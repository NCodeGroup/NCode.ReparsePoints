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
using System.Management.Automation;
using NCode.ReparsePoints;

namespace cReparsePoints
{
  [OutputType(typeof(bool))]
  [Cmdlet("Test", "TargetResource")]
  public class TestTargetResource : PSCmdlet
  {
    private Ensure _ensure;
    private LinkType _linkType;

    [Parameter(Mandatory = false)]
    [ValidateSet("Present", "Absent", IgnoreCase = true)]
    public string Ensure
    {
      get { return _ensure.ToString(); }
      set { _ensure = (Ensure) Enum.Parse(typeof(Ensure), value, true); }
    }

    [Parameter(Mandatory = true)]
    public string Path { get; set; }

    [Parameter(Mandatory = true)]
    [ValidateSet("Unknown", "HardLink", "Junction", "Symbolic", IgnoreCase = true)]
    public string LinkType
    {
      get { return _linkType.ToString(); }
      set { _linkType = (LinkType) Enum.Parse(typeof(LinkType), value, true); }
    }

    [Parameter(Mandatory = true)]
    public string Target { get; set; }

    protected override void ProcessRecord()
    {
      var path = Path;
      var target = Target;
      var ensure = _ensure;
      var type = _linkType;

      if (string.IsNullOrEmpty(path)) return;
      if (ensure == cReparsePoints.Ensure.Present &&
          (string.IsNullOrEmpty(target) || type == NCode.ReparsePoints.LinkType.Unknown)) return;

      var retval = false;
      var link = ReparsePointFactory.Provider.GetLink(path);
      switch (ensure)
      {
        case cReparsePoints.Ensure.Present:
          retval = link.Type == type && string.Equals(link.Target, target, StringComparison.OrdinalIgnoreCase);
          break;

        case cReparsePoints.Ensure.Absent:
          retval = link.Type == NCode.ReparsePoints.LinkType.Unknown;
          break;
      }
      WriteObject(retval);
    }

  }
}
