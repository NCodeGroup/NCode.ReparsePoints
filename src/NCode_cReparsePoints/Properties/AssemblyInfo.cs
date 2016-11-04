#region Copyright Preamble
//
//    Copyright © 2015 NCode Group
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
//
#endregion

using System;
using System.Reflection;
using System.Resources;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("NCode_cReparsePoints")]
[assembly: AssemblyProduct("NCode_cReparsePoints")]
[assembly: AssemblyDescription("Contains a DSC resource for creating and inspecting win32 file and folder reparse points such as hard links, junctions (aka soft links), and symbolic links.")]
[assembly: AssemblyCompany("NCode Group")]
[assembly: AssemblyCopyright("Copyright © 2016 NCode Group")]
[assembly: AssemblyTrademark("")]

[assembly: AssemblyCulture("")]
[assembly: NeutralResourcesLanguage("en-us")]

#if DEBUG
[assembly: AssemblyConfiguration("Debug")]
#else
[assembly: AssemblyConfiguration("Release")]
#endif

[assembly: ComVisible(false)]
[assembly: CLSCompliant(false)]
[assembly: Guid("19b96e1c-6765-4b65-a348-7bc23176240b")]

[assembly: AssemblyVersion("1.0.0")]
[assembly: AssemblyFileVersion("1.0.0")]
[assembly: AssemblyInformationalVersion("1.0.0")]
