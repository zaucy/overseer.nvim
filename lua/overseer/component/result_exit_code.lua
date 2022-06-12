local constants = require("overseer.constants")
local STATUS = constants.STATUS
local parsers = require("overseer.parsers")

return {
  name = "result_exit_code",
  description = "Sets status based on exit code",
  params = {
    success_codes = {
      type = "list",
      optional = true,
      description = "Additional exit codes to consider as success",
    },
    parser = { optional = true },
  },
  constructor = function(params)
    local success_codes = vim.tbl_map(function(code)
      return tonumber(code)
    end, params.success_codes or {})
    table.insert(success_codes, 0)
    return {
      on_init = function(self, task)
        self.parser = parsers.get_parser(params.parser, task)
        if self.parser then
          local cb = function(key, result)
            task:dispatch("on_stream_result", key, result)
          end
          self.parser:subscribe(cb)
          self.parser_sub = cb
        end
      end,
      on_dispose = function(self)
        if self.parser and self.parser_sub then
          self.parser:unsubscribe(self.parser_sub)
          self.parser_sub = nil
        end
      end,
      on_reset = function(self)
        if self.parser then
          self.parser:reset()
        end
      end,
      on_output_lines = function(self, task, lines)
        if self.parser then
          self.parser:ingest(lines)
        end
      end,
      on_exit = function(self, task, code)
        local status = vim.tbl_contains(success_codes, code) and STATUS.SUCCESS or STATUS.FAILURE
        local result
        if self.parser then
          result = self.parser:get_result()
        else
          result = task.result or {}
        end
        task:set_result(status, result)
      end,
    }
  end,
}