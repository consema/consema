// Consema's repository-owned .NET 10 IniConfigurationProvider differential adapter.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration.Ini;

internal sealed class ObservableIniProvider : IniConfigurationProvider
{
    internal ObservableIniProvider() : base(new IniConfigurationSource())
    {
    }

    internal IEnumerable<KeyValuePair<string, string?>> OrderedEntries()
    {
        return Data.OrderBy(entry => entry.Key, StringComparer.Ordinal);
    }
}

internal static class Program
{
    private static string Transport(string value)
    {
        return Convert.ToHexString(Encoding.UTF8.GetBytes(value)).ToLowerInvariant();
    }

    private static void RuntimeFacts()
    {
        Assembly assembly = typeof(IniConfigurationProvider).Assembly;
        string informational = assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion ?? string.Empty;
        Console.WriteLine($"dotnet.framework\t{RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"dotnet.runtime-version\t{Environment.Version}");
        Console.WriteLine($"os.description\t{RuntimeInformation.OSDescription}");
        Console.WriteLine($"os.architecture\t{RuntimeInformation.OSArchitecture}");
        Console.WriteLine($"process.architecture\t{RuntimeInformation.ProcessArchitecture}");
        Console.WriteLine($"ini.assembly-version\t{assembly.GetName().Version}");
        Console.WriteLine($"ini.informational-version\t{informational}");
    }

    private static void RunCase(string path)
    {
        byte[] source = File.ReadAllBytes(path);
        Console.WriteLine($"input-sha256\t{Convert.ToHexString(SHA256.HashData(source)).ToLowerInvariant()}");
        try
        {
            var provider = new ObservableIniProvider();
            using var stream = new MemoryStream(source, writable: false);
            provider.Load(stream);
            Console.WriteLine("complete");
            foreach (KeyValuePair<string, string?> entry in provider.OrderedEntries())
            {
                if (entry.Value is null)
                {
                    throw new InvalidDataException("IniConfigurationProvider published a null value");
                }
                Console.WriteLine($"entry\t{Transport(entry.Key)}\t{Transport(entry.Value)}");
            }
        }
        catch (Exception error) when (error is FormatException or InvalidDataException)
        {
            Console.WriteLine($"failed\t{error.GetType().FullName}");
        }
    }

    private static int Main(string[] args)
    {
        Console.OutputEncoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
        if (args.SequenceEqual(new[] { "--runtime" }))
        {
            RuntimeFacts();
            return 0;
        }
        if (args.Length != 1)
        {
            Console.Error.WriteLine("usage: DotnetIniOracle <input> | --runtime");
            return 2;
        }
        RunCase(args[0]);
        return 0;
    }
}
