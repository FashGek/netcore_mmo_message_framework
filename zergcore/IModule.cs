using Zerg.Core;

namespace Zerg.Module {
    public interface IZergModule {
        /// <summary>
        /// 初始化一个模块
        /// </summary>
        void Init (IContext contex, string param = "");
        /// <summary>
        /// 关闭一个模块
        /// </summary>
        void Shutdown ();
    }
}