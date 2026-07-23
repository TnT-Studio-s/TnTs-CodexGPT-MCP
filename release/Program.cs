using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

namespace CodexBuddy.Release
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(Path.GetTempPath(), "CodexBuddy-" + Guid.NewGuid().ToString("N") + ".ps1");

            try
            {
                Assembly assembly = Assembly.GetExecutingAssembly();
                string resourceName = assembly.GetManifestResourceNames()
                    .FirstOrDefault(name => name.EndsWith("CodexBuddy.ps1", StringComparison.OrdinalIgnoreCase));

                if (resourceName == null)
                {
                    Console.Error.WriteLine("Embedded CodexBuddy.ps1 was not found.");
                    return 1;
                }

                using (Stream resource = assembly.GetManifestResourceStream(resourceName))
                {
                    if (resource == null)
                    {
                        Console.Error.WriteLine("Embedded CodexBuddy.ps1 could not be opened.");
                        return 1;
                    }

                    using (StreamReader reader = new StreamReader(resource, new UTF8Encoding(false)))
                    {
                        File.WriteAllText(scriptPath, reader.ReadToEnd(), new UTF8Encoding(false));
                    }
                }

                string powershellPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    @"System32\WindowsPowerShell\v1.0\powershell.exe");

                ProcessStartInfo startInfo = new ProcessStartInfo
                {
                    FileName = powershellPath,
                    WorkingDirectory = root,
                    UseShellExecute = false,
                    CreateNoWindow = false,
                    Arguments = BuildArguments(scriptPath, args)
                };
                startInfo.EnvironmentVariables["CODEX_BUDDY_ROOT"] = root;

                using (Process process = Process.Start(startInfo))
                {
                    if (process == null)
                    {
                        Console.Error.WriteLine("Failed to start powershell.exe.");
                        return 1;
                    }

                    process.WaitForExit();
                    return process.ExitCode;
                }
            }
            finally
            {
                try
                {
                    if (File.Exists(scriptPath))
                    {
                        File.Delete(scriptPath);
                    }
                }
                catch
                {
                }
            }
        }

        private static string BuildArguments(string scriptPath, string[] args)
        {
            string[] baseArgs = new[]
            {
                "-STA",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                scriptPath
            };

            string[] allArgs = baseArgs.Concat(args).ToArray();
            return string.Join(" ", allArgs.Select(QuoteArgument).ToArray());
        }

        private static string QuoteArgument(string arg)
        {
            if (arg.Length == 0)
            {
                return "\"\"";
            }

            if (arg.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0)
            {
                return arg;
            }

            StringBuilder builder = new StringBuilder();
            builder.Append('"');

            int backslashCount = 0;
            foreach (char c in arg)
            {
                if (c == '\\')
                {
                    backslashCount++;
                    continue;
                }

                if (c == '"')
                {
                    builder.Append(new string('\\', backslashCount * 2 + 1));
                    builder.Append('"');
                    backslashCount = 0;
                    continue;
                }

                if (backslashCount > 0)
                {
                    builder.Append(new string('\\', backslashCount));
                    backslashCount = 0;
                }

                builder.Append(c);
            }

            if (backslashCount > 0)
            {
                builder.Append(new string('\\', backslashCount * 2));
            }

            builder.Append('"');
            return builder.ToString();
        }
    }
}
