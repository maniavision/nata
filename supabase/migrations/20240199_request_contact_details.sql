-- No phone numbers or contact details in a delivery request.
--
-- Run AFTER 20240198_nigeria_flutterwave.sql. Safe to re-run.
--
-- A sender could put their number in an item's name or notes so the
-- traveler calls them outside Nata. Item names, item notes and the
-- recipient's name are refused (nata:contact_details) when they hold:
--   * a digit run: 8 or more digits, with at most one space, dot, dash,
--     slash or bracket between each ("+242 06 123 4567"), dates aside
--     ("12/05/2024");
--   * a spelled-out number: 7 or more number words in a row, in English,
--     French or Spanish, digit groups counting their digits, at least 3
--     pieces ("zero six one two three four five", "06 / 12 / 34 / 56");
--   * a contact handle: messaging apps, "call me" phrases, emails, @handles
--     and links.
-- The app checks the same (lib/services/contact_check.dart) and says so
-- under the field; this is what holds when the app is bypassed. Requests
-- already sent are left as they are until they are edited.

-- -----------------------------------------------------------------------------
-- 1. The check
-- -----------------------------------------------------------------------------
create or replace function nata.has_contact_details(p_text text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  t      text;
  run    text;
  w      text;
  pieces int := 0;
  score  int := 0;
  number_words constant text[] := array[
    -- English
    'zero', 'oh', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
    'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
    'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
    'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
    'hundred', 'double', 'triple',
    -- French
    'un', 'une', 'deux', 'trois', 'quatre', 'cinq', 'sept', 'huit',
    'neuf', 'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
    'vingt', 'vingts', 'trente', 'quarante', 'cinquante', 'soixante', 'cent',
    'et',
    -- Spanish
    'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho',
    'nueve', 'diez', 'doce', 'trece', 'catorce', 'quince', 'dieciseis',
    'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta',
    'ochenta', 'noventa', 'cien', 'y'];
  joiners constant text[] := array['et', 'y', 'oh'];
begin
  if p_text is null or btrim(p_text) = '' then
    return false;
  end if;
  -- Lower case, without accents, with full-width digits as plain ones.
  t := translate(lower(p_text),
                 'àáâäãçèéêëìíîïñòóôöõùúûü’０１２３４５６７８９',
                 'aaaaaceeeeiiiinooooouuuu''0123456789');
  -- Dates are not phone numbers.
  t := regexp_replace(t, '(?<![\d./-])\d{1,2}[./-]\d{1,2}[./-]\d{2,4}(?![./-]?\d)', ' ', 'g');

  -- Digit runs.
  for run in select m[1] from regexp_matches(t, '(\d(?:[\s.()/-]?\d)+)', 'g') as m loop
    if length(regexp_replace(run, '\D', '', 'g')) >= 8 then
      return true;
    end if;
  end loop;

  -- Spelled-out numbers.
  foreach w in array regexp_split_to_array(t, '[^a-z0-9]+') loop
    continue when w = '';
    if w ~ '^\d+$' or w = any (number_words) then
      pieces := pieces + 1;
      if w ~ '^\d+$' then
        score := score + length(w);
      elsif not (w = any (joiners)) then
        score := score + 1;
      end if;
      if pieces >= 3 and score >= 7 then
        return true;
      end if;
    else
      pieces := 0;
      score := 0;
    end if;
  end loop;

  -- Contact handles.
  return t ~ ('\y(whats\s?app|watsapp|watsap|whatsap|wa\.me|telegram|t\.me|viber|'
              'snapchat|instagram|facebook|messenger|tiktok|'
              'call me|text me|ring me|contact me|my number|my phone|phone me|dm me|'
              'appelle[\s-]?moi|appelez[\s-]?moi|contacte[\s-]?moi|contactez[\s-]?moi|'
              'mon numero|mon tel|mon telephone|joignable|'
              'llamame|llameme|contactame|escribeme|mi numero|mi telefono)\y')
      or t ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
      or t ~ '(^|[\s(])@[a-z0-9_.]{3,}'
      or t ~ '(https?://|www\.)';
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Refused on items and recipients
-- -----------------------------------------------------------------------------
create or replace function nata.refuse_item_contact_details()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.name is not distinct from old.name
     and new.description is not distinct from old.description then
    return new;
  end if;
  if nata.has_contact_details(new.name)
     or nata.has_contact_details(new.description) then
    raise exception 'nata:contact_details';
  end if;
  return new;
end;
$$;

drop trigger if exists refuse_contact_details on nata.request_items;
create trigger refuse_contact_details
  before insert or update of name, description on nata.request_items
  for each row execute function nata.refuse_item_contact_details();

create or replace function nata.refuse_recipient_contact_details()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.name is not distinct from old.name then
    return new;
  end if;
  if nata.has_contact_details(new.name) then
    raise exception 'nata:contact_details';
  end if;
  return new;
end;
$$;

drop trigger if exists refuse_contact_details on nata.request_recipients;
create trigger refuse_contact_details
  before insert or update of name on nata.request_recipients
  for each row execute function nata.refuse_recipient_contact_details();
