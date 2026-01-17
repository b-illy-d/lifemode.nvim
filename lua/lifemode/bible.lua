local M = {}

local BOOK_ALIASES = {
  ['Gen'] = 'Genesis',
  ['Genesis'] = 'Genesis',
  ['Ex'] = 'Exodus',
  ['Exod'] = 'Exodus',
  ['Exodus'] = 'Exodus',
  ['Lev'] = 'Leviticus',
  ['Leviticus'] = 'Leviticus',
  ['Num'] = 'Numbers',
  ['Numbers'] = 'Numbers',
  ['Deut'] = 'Deuteronomy',
  ['Deuteronomy'] = 'Deuteronomy',
  ['Josh'] = 'Joshua',
  ['Joshua'] = 'Joshua',
  ['Judg'] = 'Judges',
  ['Judges'] = 'Judges',
  ['Ruth'] = 'Ruth',
  ['1Sam'] = '1 Samuel',
  ['1 Sam'] = '1 Samuel',
  ['1 Samuel'] = '1 Samuel',
  ['2Sam'] = '2 Samuel',
  ['2 Sam'] = '2 Samuel',
  ['2 Samuel'] = '2 Samuel',
  ['1Kgs'] = '1 Kings',
  ['1 Kgs'] = '1 Kings',
  ['1 Kings'] = '1 Kings',
  ['2Kgs'] = '2 Kings',
  ['2 Kgs'] = '2 Kings',
  ['2 Kings'] = '2 Kings',
  ['1Chr'] = '1 Chronicles',
  ['1 Chr'] = '1 Chronicles',
  ['1 Chronicles'] = '1 Chronicles',
  ['2Chr'] = '2 Chronicles',
  ['2 Chr'] = '2 Chronicles',
  ['2 Chronicles'] = '2 Chronicles',
  ['Ezra'] = 'Ezra',
  ['Neh'] = 'Nehemiah',
  ['Nehemiah'] = 'Nehemiah',
  ['Esth'] = 'Esther',
  ['Esther'] = 'Esther',
  ['Job'] = 'Job',
  ['Ps'] = 'Psalms',
  ['Psa'] = 'Psalms',
  ['Psalm'] = 'Psalms',
  ['Psalms'] = 'Psalms',
  ['Prov'] = 'Proverbs',
  ['Proverbs'] = 'Proverbs',
  ['Eccl'] = 'Ecclesiastes',
  ['Ecclesiastes'] = 'Ecclesiastes',
  ['Song'] = 'Song of Solomon',
  ['Song of Solomon'] = 'Song of Solomon',
  ['Isa'] = 'Isaiah',
  ['Isaiah'] = 'Isaiah',
  ['Jer'] = 'Jeremiah',
  ['Jeremiah'] = 'Jeremiah',
  ['Lam'] = 'Lamentations',
  ['Lamentations'] = 'Lamentations',
  ['Ezek'] = 'Ezekiel',
  ['Ezekiel'] = 'Ezekiel',
  ['Dan'] = 'Daniel',
  ['Daniel'] = 'Daniel',
  ['Hos'] = 'Hosea',
  ['Hosea'] = 'Hosea',
  ['Joel'] = 'Joel',
  ['Amos'] = 'Amos',
  ['Obad'] = 'Obadiah',
  ['Obadiah'] = 'Obadiah',
  ['Jonah'] = 'Jonah',
  ['Mic'] = 'Micah',
  ['Micah'] = 'Micah',
  ['Nah'] = 'Nahum',
  ['Nahum'] = 'Nahum',
  ['Hab'] = 'Habakkuk',
  ['Habakkuk'] = 'Habakkuk',
  ['Zeph'] = 'Zephaniah',
  ['Zephaniah'] = 'Zephaniah',
  ['Hag'] = 'Haggai',
  ['Haggai'] = 'Haggai',
  ['Zech'] = 'Zechariah',
  ['Zechariah'] = 'Zechariah',
  ['Mal'] = 'Malachi',
  ['Malachi'] = 'Malachi',
  ['Matt'] = 'Matthew',
  ['Matthew'] = 'Matthew',
  ['Mark'] = 'Mark',
  ['Luke'] = 'Luke',
  ['John'] = 'John',
  ['Acts'] = 'Acts',
  ['Rom'] = 'Romans',
  ['Romans'] = 'Romans',
  ['1Cor'] = '1 Corinthians',
  ['1 Cor'] = '1 Corinthians',
  ['1 Corinthians'] = '1 Corinthians',
  ['2Cor'] = '2 Corinthians',
  ['2 Cor'] = '2 Corinthians',
  ['2 Corinthians'] = '2 Corinthians',
  ['Gal'] = 'Galatians',
  ['Galatians'] = 'Galatians',
  ['Eph'] = 'Ephesians',
  ['Ephesians'] = 'Ephesians',
  ['Phil'] = 'Philippians',
  ['Philippians'] = 'Philippians',
  ['Col'] = 'Colossians',
  ['Colossians'] = 'Colossians',
  ['1Thess'] = '1 Thessalonians',
  ['1 Thess'] = '1 Thessalonians',
  ['1 Thessalonians'] = '1 Thessalonians',
  ['2Thess'] = '2 Thessalonians',
  ['2 Thess'] = '2 Thessalonians',
  ['2 Thessalonians'] = '2 Thessalonians',
  ['1Tim'] = '1 Timothy',
  ['1 Tim'] = '1 Timothy',
  ['1 Timothy'] = '1 Timothy',
  ['2Tim'] = '2 Timothy',
  ['2 Tim'] = '2 Timothy',
  ['2 Timothy'] = '2 Timothy',
  ['Titus'] = 'Titus',
  ['Phlm'] = 'Philemon',
  ['Philemon'] = 'Philemon',
  ['Heb'] = 'Hebrews',
  ['Hebrews'] = 'Hebrews',
  ['Jas'] = 'James',
  ['James'] = 'James',
  ['1Pet'] = '1 Peter',
  ['1 Pet'] = '1 Peter',
  ['1 Peter'] = '1 Peter',
  ['2Pet'] = '2 Peter',
  ['2 Pet'] = '2 Peter',
  ['2 Peter'] = '2 Peter',
  ['1John'] = '1 John',
  ['1 John'] = '1 John',
  ['2John'] = '2 John',
  ['2 John'] = '2 John',
  ['3John'] = '3 John',
  ['3 John'] = '3 John',
  ['Jude'] = 'Jude',
  ['Rev'] = 'Revelation',
  ['Revelation'] = 'Revelation',
}

function M.get_canonical_book(name)
  return BOOK_ALIASES[name]
end

function M.generate_verse_id(book, chapter, verse)
  local book_slug = book:lower():gsub('%s+', '-')
  return string.format('bible:%s:%d:%d', book_slug, chapter, verse)
end

function M.expand_range(book, chapter, verse_start, verse_end)
  local ids = {}
  for v = verse_start, verse_end do
    table.insert(ids, M.generate_verse_id(book, chapter, v))
  end
  return ids
end

function M.extract_refs(text)
  local refs = {}
  local pos = 1

  while pos <= #text do
    local num_prefix, book_name, rest_pos = text:match('^([123])%s?([A-Z][a-z]+)()', pos)

    if not num_prefix then
      book_name, rest_pos = text:match('^([A-Z][a-z]+)()', pos)
    end

    if book_name then
      local full_book = num_prefix and (num_prefix .. ' ' .. book_name) or book_name
      local canonical = M.get_canonical_book(full_book)

      if not canonical and num_prefix then
        canonical = M.get_canonical_book(num_prefix .. book_name)
      end

      if canonical then
        local after = text:sub(rest_pos)
        local chapter, verse_start, verse_end = after:match('^%s+(%d+):(%d+)%-?(%d*)')

        if chapter then
          local ch = tonumber(chapter)
          local v_start = tonumber(verse_start)
          local v_end = verse_end ~= '' and tonumber(verse_end) or v_start
          local verse_ids = M.expand_range(canonical, ch, v_start, v_end)
          table.insert(refs, {
            book = canonical,
            chapter = ch,
            verse_start = v_start,
            verse_end = v_end,
            verse_ids = verse_ids,
          })
        end
      end
    end

    local next_upper = text:find('[A-Z123]', pos + 1)
    if next_upper then
      pos = next_upper
    else
      break
    end
  end

  if #refs > 0 then
    return refs
  end
  return nil
end

function M.get_ref_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  local refs = M.extract_refs(line)
  if not refs then return nil end

  for _, ref in ipairs(refs) do
    local pattern = ref.book:gsub(' ', '%%s*') .. '%s+' .. ref.chapter .. ':' .. ref.verse_start
    if ref.verse_end ~= ref.verse_start then
      pattern = pattern .. '%-' .. ref.verse_end
    end

    local s, e = line:find(pattern)
    if s and col >= s - 1 and col <= e then
      return ref
    end
  end

  return nil
end

function M.get_verse_url(book, chapter, verse_start, verse_end, version)
  version = version or 'ESV'
  local passage = book .. '+' .. chapter .. ':' .. verse_start
  if verse_end ~= verse_start then
    passage = passage .. '-' .. verse_end
  end
  passage = passage:gsub(' ', '%%20')
  return 'https://www.biblegateway.com/passage/?search=' .. passage .. '&version=' .. version
end

function M.goto_definition(version)
  local ref = M.get_ref_at_cursor()
  if not ref then
    vim.notify('No Bible reference at cursor', vim.log.levels.INFO)
    return
  end

  local url = M.get_verse_url(ref.book, ref.chapter, ref.verse_start, ref.verse_end, version)
  vim.notify('Bible reference: ' .. ref.book .. ' ' .. ref.chapter .. ':' .. ref.verse_start ..
    (ref.verse_end ~= ref.verse_start and '-' .. ref.verse_end or ''), vim.log.levels.INFO)
  vim.notify('URL: ' .. url, vim.log.levels.INFO)
end

return M
