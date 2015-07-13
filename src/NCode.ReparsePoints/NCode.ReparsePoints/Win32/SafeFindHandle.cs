using System;
using System.Security;
using Microsoft.Win32.SafeHandles;

namespace NCode.ReparsePoints.Win32
{
	[SecurityCritical]
	internal sealed class SafeFindHandle : SafeHandleZeroOrMinusOneIsInvalid
	{
		public SafeFindHandle()
			: base(true)
		{
			// do not delete this ctor
			// it is required for pinvoke
		}

		public SafeFindHandle(IntPtr handle)
			: base(true)
		{
			SetHandle(handle);
		}

		protected override bool ReleaseHandle()
		{
			return NativeMethods.FindClose(handle);
		}

	}
}