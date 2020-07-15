using System;
using System.Collections.Concurrent;
using System.Collections.Generic;

namespace Zerg.Core {
    public class ZergHandleManager {

        public ZergHandleManager (ZergQueen queen) {
            _queen = queen;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="ctx"></param>
        public void RegisterHandle (ZergContext ctx) {
            if (ctx == null) return;
            _handles[ctx.Handle] = ctx;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="handle"></param>
        /// <returns></returns>
        public ZergContext GrabByHandle (int handle) {
            if (_handles.ContainsKey (handle)) return _handles[handle];
            return null;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="name"></param>
        /// <returns></returns>
        public ZergContext GrabByName (string name) {
            if (_namedHandles.ContainsKey (name)) return _handles[_namedHandles[name]];
            return null;
        }

        public void HandleRetire (IContext ctx) {
            if (_handles.ContainsKey (ctx.Handle)) {
                _handles.TryRemove (ctx.Handle, out _);
            }

            for (int i = 0; i < _namedHandles.Count; i++) {

            }

            // var toRemove = new ConcurrentDictionary<string, int> ();

            // System.Threading.Tasks.Parallel.ForEach (_namedHandles, (KVP, loopState) => {
            //     if (KVP.Value == ctx.Handle) {
            //         toRemove.TryAdd(KVP);
            //     }
            // });

            // foreach (var item in toRemove) {
            //     dictObject.Remove (item.Key);
            // }

        }

        internal void ReleaseAll () {
            ZergMessage exitMsg = new ZergMessage ();
            exitMsg.MsgType = (int) ZergMessage.Type.EXIT;
            foreach (KeyValuePair<int, ZergContext> kv in _handles) {
                kv.Value.Push (exitMsg);
            }
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="handle"></param>
        /// <param name="name"></param>
        public void NameHandle (int handle, string name) {
            if (name.Length > 0 && !_namedHandles.ContainsKey (name)) _namedHandles[name] = handle;
        }

        public void NameHandle (ZergContext context, string name) {
            if (context != null && name.Length > 0 && !_namedHandles.ContainsKey (name)) _namedHandles[name] = context.Handle;
        }

        private ConcurrentDictionary<int, ZergContext> _handles = new ConcurrentDictionary<int, ZergContext> ();
        private ConcurrentDictionary<string, int> _namedHandles = new ConcurrentDictionary<string, int> ();
        private ZergQueen _queen;

    }
}