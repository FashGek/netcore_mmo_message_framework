using Zerg.Module;

namespace Zerg.Core
{

    public delegate void Hookdelegate(int type, int session, int source, object msg);

    public interface IContext
    {
        IZergModule ModuleInstance { get; }
        ZergQueen Queen { get; }
        int Handle { get; }
        Hookdelegate Hook { get; set; }
        int Send(int source, int destination, int type, int session, object data, int sz = 0);
        int NewSession();
    }
}
