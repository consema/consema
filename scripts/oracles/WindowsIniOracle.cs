// Consema's repository-owned GetPrivateProfileStringW differential adapter.

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Consema.Oracle
{
    public static class WindowsIniOracle
    {
        private const int InitialCapacity = 256;
        private const int MaximumCapacity = 65536;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetPrivateProfileString(
            string section,
            string key,
            string defaultValue,
            [Out] char[] output,
            uint size,
            string fileName);

        public static string ReadValue(
            string absolutePath,
            string section,
            string key,
            string defaultValue)
        {
            int capacity = InitialCapacity;
            while (capacity <= MaximumCapacity)
            {
                char[] buffer = new char[capacity];
                uint length = GetPrivateProfileString(
                    section,
                    key,
                    defaultValue,
                    buffer,
                    (uint)buffer.Length,
                    absolutePath);
                if (length < buffer.Length - 1)
                {
                    return new string(buffer, 0, (int)length);
                }
                capacity *= 2;
            }
            throw new InvalidOperationException("Windows INI value exceeds oracle buffer limit");
        }

        public static string[] ReadSections(string absolutePath)
        {
            return ReadMultiString(absolutePath, null, null);
        }

        public static string[] ReadKeys(string absolutePath, string section)
        {
            return ReadMultiString(absolutePath, section, null);
        }

        private static string[] ReadMultiString(
            string absolutePath,
            string section,
            string key)
        {
            int capacity = InitialCapacity;
            while (capacity <= MaximumCapacity)
            {
                char[] buffer = new char[capacity];
                uint length = GetPrivateProfileString(
                    section,
                    key,
                    string.Empty,
                    buffer,
                    (uint)buffer.Length,
                    absolutePath);
                if (length < buffer.Length - 2)
                {
                    List<string> values = new List<string>();
                    int start = 0;
                    for (int index = 0; index < length; index++)
                    {
                        if (buffer[index] != '\0')
                        {
                            continue;
                        }
                        values.Add(new string(buffer, start, index - start));
                        start = index + 1;
                    }
                    if (start < length)
                    {
                        values.Add(new string(buffer, start, (int)length - start));
                    }
                    return values.ToArray();
                }
                capacity *= 2;
            }
            throw new InvalidOperationException("Windows INI list exceeds oracle buffer limit");
        }
    }
}
