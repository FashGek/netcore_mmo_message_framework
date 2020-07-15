using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace Zerg.Core {
    public class ZergTimer {

        public const int FPS = 30;
        /// <summary>
        /// 30fps = 33ms
        /// 120fps = 8ms
        /// </summary>
        /// <param name="FPS"></param>
        /// <returns></returns>
        public static readonly int TICK = 33;// = (1 / FPS) * 1000;

        public class ZergTimerNode {
            public int Handle { get; set; }
            public int Session { get; set; }
            public long Expire { get; set; }
            public bool Remove { get; set; }
            public ZergTimerNode (int handle, int session) {
                Handle = handle;
                Session = session;
                Remove = false;
            }

            public ZergTimerNode(ZergMessage msg) {

            }
        }

        public ZergTimer (ZergQueen queen) {
            _queen = queen;
            _watch = Stopwatch.StartNew ();
            _nodeList = new List<ZergTimerNode> ();
            _Starttime = (DateTime.Now.ToUniversalTime ().Ticks - 621355968000000000) / 10000000;
        }

        /// <summary>
        /// 这个Task执行的函数
        /// </summary>
        public void Tick () {
            _nodeList.AsParallel ().Where (node => node.Expire <= _watch.ElapsedMilliseconds).ToList ().ForEach (n => {
                var msg = new ZergMessage ();
                msg.Session = n.Session;
                msg.Source = n.Handle;
                msg.MsgType = (int) ZergMessage.Type.RESPONSE;
                msg.Data = "";

                var ctx = _queen.HandleManager.GrabByHandle(n.Handle);
                if (ctx != null) {
                    ctx.Push (msg);
                }

                n.Remove = true;
            });

            _nodeList.RemoveAll (n => n.Remove);
        }

        /// <summary>
        /// 某个模块要在多少时间之后超时,然后给这个模块通知一条消息
        /// </summary>
        /// <param name="handle"></param>
        /// <param name="time"></param>
        /// <param name="session"></param>
        public void Timeout (int handle, int time, int session) {
            if (time <= 0) {
                var msg = new ZergMessage ();
                msg.Source = handle;
                msg.Session = session;
                msg.MsgType = (int) ZergMessage.Type.RESPONSE;
                msg.Data = "";

                var ctx = _queen.HandleManager.GrabByHandle (handle);
                if (ctx != null) {
                    ctx.Push (msg);
                }
            } else {
                AddTimer (handle, time, session);
            }
        }

        internal void Timeout(ZergMessage msg, int time)
        {
            if (time <= 0) {
                var ctx = _queen.HandleManager.GrabByHandle (msg.Source);
                if (ctx != null) {
                    ctx.Push (msg);
                }
            } else {
            }
        }

        private void AddTimer (int handle, int time, int session) {
            var timerNode = new ZergTimerNode (handle, session);
            timerNode.Expire = time + _watch.ElapsedMilliseconds;
            _nodeList.Add (timerNode);
        }

        /// <summary>
        /// 获取当前时间
        /// </summary>
        /// <returns></returns>
        public long ElapsedTime () {
            return _watch.ElapsedMilliseconds / 1000;
        }

        private ZergQueen _queen;
        private Stopwatch _watch;
        private List<ZergTimerNode> _nodeList;
        private long _Starttime;

        public long Starttime { get => _Starttime; }
    }
}