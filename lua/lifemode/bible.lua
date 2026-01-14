-- Bible reference parsing for LifeMode
-- Extracts Bible references from text and generates deterministic verse IDs

local M = {}

-- Book name mapping: abbreviated/full name -> canonical name
-- Canonical names are lowercase with no spaces (e.g., "genesis", "1corinthians")
local BOOK_NAMES = {
  -- Old Testament
  ["genesis"] = "genesis",
  ["gen"] = "genesis",
  ["exodus"] = "exodus",
  ["ex"] = "exodus",
  ["exod"] = "exodus",
  ["leviticus"] = "leviticus",
  ["lev"] = "leviticus",
  ["numbers"] = "numbers",
  ["num"] = "numbers",
  ["deuteronomy"] = "deuteronomy",
  ["deut"] = "deuteronomy",
  ["joshua"] = "joshua",
  ["josh"] = "joshua",
  ["judges"] = "judges",
  ["judg"] = "judges",
  ["ruth"] = "ruth",
  ["1samuel"] = "1samuel",
  ["1sam"] = "1samuel",
  ["2samuel"] = "2samuel",
  ["2sam"] = "2samuel",
  ["1kings"] = "1kings",
  ["2kings"] = "2kings",
  ["1chronicles"] = "1chronicles",
  ["1chron"] = "1chronicles",
  ["2chronicles"] = "2chronicles",
  ["2chron"] = "2chronicles",
  ["ezra"] = "ezra",
  ["nehemiah"] = "nehemiah",
  ["neh"] = "nehemiah",
  ["esther"] = "esther",
  ["est"] = "esther",
  ["job"] = "job",
  ["psalm"] = "psalms",
  ["psalms"] = "psalms",
  ["ps"] = "psalms",
  ["proverbs"] = "proverbs",
  ["prov"] = "proverbs",
  ["ecclesiastes"] = "ecclesiastes",
  ["eccl"] = "ecclesiastes",
  ["songofsolomon"] = "songofsolomon",
  ["song"] = "songofsolomon",
  ["isaiah"] = "isaiah",
  ["isa"] = "isaiah",
  ["jeremiah"] = "jeremiah",
  ["jer"] = "jeremiah",
  ["lamentations"] = "lamentations",
  ["lam"] = "lamentations",
  ["ezekiel"] = "ezekiel",
  ["ezek"] = "ezekiel",
  ["daniel"] = "daniel",
  ["dan"] = "daniel",
  ["hosea"] = "hosea",
  ["hos"] = "hosea",
  ["joel"] = "joel",
  ["amos"] = "amos",
  ["obadiah"] = "obadiah",
  ["obad"] = "obadiah",
  ["jonah"] = "jonah",
  ["micah"] = "micah",
  ["mic"] = "micah",
  ["nahum"] = "nahum",
  ["nah"] = "nahum",
  ["habakkuk"] = "habakkuk",
  ["hab"] = "habakkuk",
  ["zephaniah"] = "zephaniah",
  ["zeph"] = "zephaniah",
  ["haggai"] = "haggai",
  ["hag"] = "haggai",
  ["zechariah"] = "zechariah",
  ["zech"] = "zechariah",
  ["malachi"] = "malachi",
  ["mal"] = "malachi",

  -- New Testament
  ["matthew"] = "matthew",
  ["matt"] = "matthew",
  ["mark"] = "mark",
  ["luke"] = "luke",
  ["john"] = "john",
  ["acts"] = "acts",
  ["romans"] = "romans",
  ["rom"] = "romans",
  ["1corinthians"] = "1corinthians",
  ["1cor"] = "1corinthians",
  ["2corinthians"] = "2corinthians",
  ["2cor"] = "2corinthians",
  ["galatians"] = "galatians",
  ["gal"] = "galatians",
  ["ephesians"] = "ephesians",
  ["eph"] = "ephesians",
  ["philippians"] = "philippians",
  ["phil"] = "philippians",
  ["colossians"] = "colossians",
  ["col"] = "colossians",
  ["1thessalonians"] = "1thessalonians",
  ["1thess"] = "1thessalonians",
  ["2thessalonians"] = "2thessalonians",
  ["2thess"] = "2thessalonians",
  ["1timothy"] = "1timothy",
  ["1tim"] = "1timothy",
  ["2timothy"] = "2timothy",
  ["2tim"] = "2timothy",
  ["titus"] = "titus",
  ["philemon"] = "philemon",
  ["phile"] = "philemon",
  ["hebrews"] = "hebrews",
  ["heb"] = "hebrews",
  ["james"] = "james",
  ["jas"] = "james",
  ["1peter"] = "1peter",
  ["1pet"] = "1peter",
  ["2peter"] = "2peter",
  ["2pet"] = "2peter",
  ["1john"] = "1john",
  ["2john"] = "2john",
  ["3john"] = "3john",
  ["jude"] = "jude",
  ["revelation"] = "revelation",
  ["rev"] = "revelation",
}

--- Normalize book name to canonical form
--- @param book string Book name (may be abbreviated, mixed case)
--- @return string|nil Canonical book name or nil if not recognized
local function normalize_book_name(book)
  -- Remove spaces and convert to lowercase
  local normalized = book:lower():gsub("%s+", "")
  return BOOK_NAMES[normalized]
end

--- Extract Bible references from text
--- Supports single verses, ranges, and multiple references (separated by semicolons or in text)
--- @param text string Text to search for Bible references
--- @return table Array of refs with format { target = "bible:book:ch:v", type = "bible_verse" }
function M.parse_bible_refs(text)
  local all_refs = {}

  -- Pattern to match Bible references in text
  -- Matches: Book Chapter:Verse or Chapter:Verse-Verse
  -- Book can be: optional number, optional space, letters
  -- Examples: "John 3:16", "1 Cor 13:4", "Rom 8:28-30"
  local pattern = "([%d]?%s?[%a]+)%s+(%d+):(%d+)%-?(%d*)"

  for book, chapter, verse_start, verse_end in text:gmatch(pattern) do
    -- Normalize book name
    local canonical_book = normalize_book_name(book)

    if canonical_book then
      -- Convert chapter and verses to numbers
      local chapter_num = tonumber(chapter)
      local verse_start_num = tonumber(verse_start)
      local verse_end_num = verse_end ~= "" and tonumber(verse_end) or verse_start_num

      -- Generate verse IDs
      for v = verse_start_num, verse_end_num do
        table.insert(all_refs, {
          target = string.format("bible:%s:%d:%d", canonical_book, chapter_num, v),
          type = "bible_verse"
        })
      end
    end
  end

  return all_refs
end

return M
