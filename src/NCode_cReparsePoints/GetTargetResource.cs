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

using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using NCode.ReparsePoints;

namespace cReparsePoints
{
  [OutputType(typeof(Hashtable))]
  [Cmdlet(VerbsCommon.Get, "TargetResource")]
  public class GetTargetResource : PSCmdlet
  {
    [Parameter(Mandatory = true)]
    public string Path { get; set; }

    protected override void ProcessRecord()
    {
      var response = new Dictionary<string, string>();
      var link = ReparsePointFactory.Provider.GetLink(Path);
      if (link.Type != LinkType.Unknown)
      {
        response["Ensure"] = "Present";
        response["LinkType"] = link.Type.ToString();
        response["Target"] = link.Target;
      }
      else
      {
        response["Ensure"] = "Absent";
        response["LinkType"] = "Unknown";
        response["Target"] = string.Empty;
      }
      WriteObject(response);
    }

  }
}
