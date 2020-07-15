using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.Loader;

namespace Zerg.Core {
    internal class ZergModuleManger {
        public ZergModuleManger (string dllPath) {
            _dllPath = dllPath;
        }

        public Type QueryModule (string name) {
            Type dll;
            if (_modules.ContainsKey (name.ToLower ())) {
                dll = _modules[name.ToLower ()];
            } else {
                dll = tryOpen (name);
            }

            return dll;
        }

        /// <summary>
        /// 1. 所有的Module都要求是在Zerg.Core.Module这个文件夹
        /// 2. 命名规范类名与文件名相同
        /// 3. 由于反射相关的dll必须是绝对路径,所以提供的路径必须是以zerg.exe所在路径去找
        /// 4. ?.dll中的?号会被替换为相应的模块名
        /// </summary>
        /// <param name="name"></param>
        /// <returns></returns>
        Type tryOpen (string name) {
            var modules = _dllPath.Split (';');
            if (modules.Length <= 0) return null;

            foreach (var m in modules) {
                var lookupModule = m.Replace ("?", name.ToLower ());

                // var d = File.ReadAllBytes(ZergEnv.ExePath + lookupModule);
                // string key = "--fa------------fds%-afdsjlafjafd fdjalfdjaf0dsaf******Fsafs";
                // var dd = Xxtea.XXTEA.Decrypt(d, key);
                // var s = new MemoryStream(dd);
                // var moduleAssembly = AssemblyLoadContext.Default.LoadFromStream(s);
                var moduleAssembly = AssemblyLoadContext.Default.LoadFromAssemblyPath (ZergEnv.ExePath + lookupModule);
                var moduleMeta = moduleAssembly.GetType (ModuleNamespace + name);

                _modules[name.ToLower ()] = moduleMeta;
            }

            return _modules.ContainsKey (name.ToLower ()) ? _modules[name.ToLower ()] : null;
        }

        readonly string ModuleNamespace = "Zerg.Module.";

        Dictionary<string, Type> _modules = new Dictionary<string, Type> ();
        private string _dllPath;
    }
}