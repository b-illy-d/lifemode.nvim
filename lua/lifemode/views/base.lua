local M = {}

local instance_counter = 0

function M.next_id(prefix)
  instance_counter = instance_counter + 1
  return (prefix or 'inst') .. '_' .. instance_counter
end

function M.reset_counter()
  instance_counter = 0
end

function M.create_output()
  return { lines = {}, spans = {}, highlights = {} }
end

function M.apply_lens_result(result, indent, current_line, output)
  for _, content_line in ipairs(result.lines) do
    table.insert(output.lines, indent .. content_line)
    for _, hl in ipairs(result.highlights) do
      table.insert(output.highlights, {
        line = current_line,
        col_start = #indent + hl.col_start,
        col_end = #indent + hl.col_end,
        hl_group = hl.hl_group,
      })
    end
    current_line = current_line + 1
  end
  return current_line
end

function M.add_span(output, span_data)
  table.insert(output.spans, span_data)
end

function M.get_indent(depth, indent_str)
  return string.rep(indent_str or '  ', depth)
end

return M
