using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using Neo.IronLua;
using Zerg.Core;
using Zerg.Core.MsgData;

namespace Zerg.Core {
    public class ZergUtils {

        public static byte[] LuaToBin (params object[] data) {
            var stream = new MemoryStream ();
            var formatter = new BinaryFormatter ();

            foreach (var d in data) {
                if (d is ValueType) {
                    formatter.Serialize (stream, d);
                } else if (d is LuaTable) {
                    var t = d as LuaTable;
                    if (t != null) {
                        var j = t.ToLson ();
                        formatter.Serialize (stream, j);
                    }
                } else if (d is string) {
                    formatter.Serialize (stream, d);
                }
            }
            stream.Close ();
            return stream.ToArray ();
        }

        public static object[] BinToLua (byte[] buf) {
            BinaryFormatter bf = new BinaryFormatter ();
            MemoryStream ms = new MemoryStream (buf);

            List<Object> l = new List<object> ();
            while (ms.Position != ms.Length) {
                object d = bf.Deserialize (ms);

                if (d is bool) {
                    l.Add ((bool) d);
                } else if (d is string) {
                    try {
                        var s = (string) d;
                        if (s.StartsWith ('{') && s.EndsWith ('}')) {
                            try {
                                var j = LuaTable.FromLson (s);
                                l.Add (j);
                            } catch (Exception) {
                                l.Add (s);
                            }
                        } else {
                            l.Add (s);
                        }
                    } catch (Exception) {
                        l.Add ((string) d);
                    }
                } else if (IsNumber (d)) {
                    double number;
                    Double.TryParse (Convert.ToString (d, CultureInfo.InvariantCulture),
                        System.Globalization.NumberStyles.Any,
                        NumberFormatInfo.InvariantInfo, out number);

                    l.Add (number);
                }
            }

            return l.ToArray ();
        }

        public static MemoryStream SerializeToStream (SpStream spstream) {
            MemoryStream stream = new MemoryStream ();
            IFormatter formatter = new BinaryFormatter ();
            formatter.Serialize (stream, spstream);
            return stream;
        }

        public static SpStream DeserializeFromStream (MemoryStream stream) {
            IFormatter formatter = new BinaryFormatter ();
            stream.Seek (0, SeekOrigin.Begin);
            object o = formatter.Deserialize (stream);
            return o as SpStream;
        }

        public static byte[] ReadFully (MemoryStream input) {
            byte[] buffer = new byte[16 * 1024];
            using (MemoryStream ms = new MemoryStream ()) {
                int read;
                while ((read = input.Read (buffer, 0, buffer.Length)) > 0) {
                    ms.Write (buffer, 0, read);
                }
                return ms.ToArray ();
            }
        }

        public static bool IsNumber (object value) {
            return value is sbyte ||
                value is byte ||
                value is short ||
                value is ushort ||
                value is int ||
                value is uint ||
                value is long ||
                value is ulong ||
                value is float ||
                value is double ||
                value is decimal;
        }
    }
}