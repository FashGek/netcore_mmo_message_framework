using System;
using MoonSharp.Interpreter;

namespace Zerg.Core {
    public class ZergEnv {

        public static readonly string ExePath = AppDomain.CurrentDomain.BaseDirectory;

        /// <summary>
        /// ��������������쳣,��������׶ε��쳣���쳣
        /// 所以root是以zerg.exe或者zerg.dll所在的目录为root，其余的也都应当以它作为相对目录
        /// </summary>
        /// <param name="file">�����ļ���lua��ʽ</param>
        public ZergEnv (string file) {
            Script state = new Script ();
            //state.Globals.Set("root", DynValue.NewString(ExePath));
            // state.Globals["root"] = ExePath;
            var func = state.LoadString (code);
            var t = state.Call (func, file);
            _table = t.Table;
        }

        public string GetEnv (string k) {
            return _table[k] == null ? "" : _table[k] as string;
        }

        public void SetEnv (string k, string v) {
            if (k != null && k.Length > 0 && v != null && v.Length > 0) {
                _table[k] = v;
            }
        }

        Table _table;

        string code = @"
            local result = {}
                local function getenv(name) 
                    return assert(os.getenv(name), [[os.getenv() failed]] .. name)
                end                 
                local sep = package.config:sub(1, 1)
                local current_path = [[.]] .. sep
                local function include(filename)
                    local last_path = current_path
                    local path, name = filename:match([[(.*]]..sep..[[)(.*)$]])
                    if path then
                        if path:sub(1, 1) == sep then
                            current_path = path
                        else
                            current_path = path --current_path .. path
                        end
                    else
                        name = filename
                    end
                    local f = assert(io.open(current_path .. name))
                    local code = assert(f:read [[*a]])
                    code = string.gsub(code, [[%$([%w_%d]+)]], getenv)
                    f:close()
                    assert(load(code,[[@]]..filename,[[t]],result))()
                    current_path = last_path
                end
                setmetatable(result, { _index = {include = include } })
                local config_name = ...
                include(config_name)
                setmetatable(result, nil)
                return result
        ";
    }
}