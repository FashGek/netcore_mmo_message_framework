using System;
using System.Collections.Concurrent;

namespace Zerg.Core {
    public class ZergGlobalQueue {

        public void Push (ZergMessageQueue queue) {
            _queue.Add (queue);
        }

        public ZergMessageQueue Pop () {
            return _queue.Take ();
        }

        private BlockingCollection<ZergMessageQueue> _queue = new BlockingCollection<ZergMessageQueue>();
    }
}