using System;
using System.Threading;
using System.Threading.Tasks;

namespace Zerg.Shell {
    class Program {
        static void Main (string[] args) {
            if (args.Length <= 0) {
                Console.WriteLine ("dotnet ./bin/zerg.dll config or zerg config");
                return;
            }
            var exitEvent = new ManualResetEvent (false);

            Zerg.Core.ZergQueen zerg = new Zerg.Core.ZergQueen (args[0]);
            // Console.CancelKeyPress += (sender, eventArgs) => {
            //     eventArgs.Cancel = true;
            //     exitEvent.Set ();

            //     zerg.Die ();
            // };

            


            zerg.Start ();

            // exitEvent.WaitOne ();
        }
    }
}