-- Фильтр pandoc для build-doc:
--   ссылки *.md -> *.html, dict/X.tsv -> dict.html#dict-X, dict -> dict.html, каталог БД -> db.html;
--   функции на странице функций получают якорь по коду (Ф-ПЛТ-01): заголовок с кодом (вдобавок к якорю заголовка)
--   или ячейка таблицы из одного кода;
--   коды функций в тексте становятся ссылками на определение.
-- Переменные окружения: DOC_PAGE - текущая страница (имя файла без .md), DOC_FUNC_PAGE - страница функций
-- (пусто - коды не трогаются), DOC_DB_LINK - каталог описания БД относительно doc (пусто - нет db.html).

local page = os.getenv("DOC_PAGE") or ""
local FUNC_PAGE = os.getenv("DOC_FUNC_PAGE") or ""
local DB_LINK = os.getenv("DOC_DB_LINK") or ""

-- Ф-, код группы (заглавные буквы А-Я, в UTF-8 - байты \208\144-\208\175), -, две цифры
local CODE = "Ф%-[\208\144-\175]+%-%d%d"

local function html_name(name)
  if name == "readme" then return "index" end
  return name
end

function Link(el)
  local t = el.target
  local name, anchor = t:match("^([^/:#]+)%.md(#?.*)$")
  if name then
    el.target = html_name(name) .. ".html" .. anchor
    return el
  end
  local dict = t:match("^dict/([^/]+)%.tsv$")
  if dict then
    el.target = "dict.html#dict-" .. dict
    return el
  end
  if t == "dict" or t == "dict/" then
    el.target = "dict.html"
    return el
  end
  if DB_LINK ~= "" and (t == DB_LINK or t == DB_LINK .. "/") then
    el.target = "db.html"
    return el
  end
end

local function func_href(code)
  if page == FUNC_PAGE then return "#" .. code end
  return FUNC_PAGE .. ".html#" .. code
end

-- Разбивает Str на текст и ссылки на коды функций
local function split_str(s, out)
  local pos = 1
  while true do
    local i, j = s:find(CODE, pos)
    if not i then break end
    if i > pos then out[#out + 1] = pandoc.Str(s:sub(pos, i - 1)) end
    local code = s:sub(i, j)
    out[#out + 1] = pandoc.Link({ pandoc.Str(code) }, func_href(code))
    pos = j + 1
  end
  if pos <= #s then out[#out + 1] = pandoc.Str(s:sub(pos)) end
end

-- Обходит инлайны, не заходя в ссылки и код
local function link_codes(inlines)
  local out = {}
  for _, el in ipairs(inlines) do
    if el.t == "Str" then
      split_str(el.text, out)
    elseif el.t == "Link" or el.t == "Code" then
      out[#out + 1] = el
    else
      if el.content and type(el.content) == "table" and el.t ~= "Note" then
        el.content = link_codes(el.content)
      end
      out[#out + 1] = el
    end
  end
  return out
end

function Para(el)
  if FUNC_PAGE == "" then return end
  el.content = link_codes(el.content)
  return el
end

function Plain(el)
  if FUNC_PAGE == "" then return end
  if page == FUNC_PAGE then
    local text = pandoc.utils.stringify(el.content)
    if text:match("^" .. CODE .. "$") then
      el.content = { pandoc.Span({ pandoc.Str(text) }, pandoc.Attr(text)) }
      return el
    end
  end
  el.content = link_codes(el.content)
  return el
end

function Header(el)
  if FUNC_PAGE ~= "" and page == FUNC_PAGE then
    local code = pandoc.utils.stringify(el.content):match(CODE)
    if code then
      -- якорь по коду - пустой span; якорь заголовка как на GitHub остаётся для ссылок из .md
      table.insert(el.content, 1, pandoc.Span({}, pandoc.Attr(code)))
      return el
    end
  end
end
