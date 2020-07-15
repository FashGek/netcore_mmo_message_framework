namespace Zerg.Core {
    public class ZergMessage {
        public enum Type {
            TEXT,
            RESPONSE,
            CLIENT,
            SERVER,
            SYSTEM,
            SOCKET,
            ERROR = 7,
            LUA = 10,
            LOG,
            EXIT
        }

        public enum Tag : uint {
            AllocSession = 0x20000000,
            MsgMask = 0x00ffffff,
        }

        public static readonly ZergMessage Dummy = new ZergMessage ();

        public int Source { get; set; }

        public int Session { get; set; }
        /// <summary>
        /// Session 是一个32位的整数,但是这里会把它切开为低/高两部分,高位存储一些session 标志, 低位存储session值
        /// 11111111    111001111111111111110001
        /// msg_tag msg
        /// 也就意味着支持8种tag, 以及2^24的session号
        /// </summary>
        public int MsgType { get; set; }
        public object Data { get; set; }
        public bool CanRemail{
            get =>
                RemailCount > 1;
        }
        public void IncMailcount() => RemailCount++;
        private int RemailCount = 0;
        public static readonly int MaxRemailCount = 1;
    }
}