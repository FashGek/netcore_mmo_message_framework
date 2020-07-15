using System;
using System.Collections.Concurrent;

namespace Zerg.Core {
    public class ZergMessageQueue {
        public int ContextHandle { get => _contex.Handle; }

        public ZergMessageQueue (IContext context) {
            _contex = context;
        }
        internal bool Pop (out ZergMessage msg) {
            return _queue.TryDequeue(out msg);
        }

        internal void Push (ZergMessage msg) {
            _queue.Enqueue (msg);
        }

        private IContext _contex;

        private ConcurrentQueue<ZergMessage> _queue = new ConcurrentQueue<ZergMessage> ();
    }
}