using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
using NCode.ReparsePoints.Win32;

namespace NCode.ReparsePoints
{
	public interface IReparsePointProvider
	{
		LinkType GetLinkType(string path);

		string GetTarget(string path);

		void CreateLink(string path, string target, LinkType type);
	}

	public class ReparsePointProvider : IReparsePointProvider
	{
		#region IReparsePointProvider Members

		public virtual LinkType GetLinkType(string path)
		{
			WIN32_FIND_DATA data;
			using (var handle = NativeMethods.FindFirstFile(path, out data))
			{
				if (handle.IsInvalid)
					return LinkType.Unknown;

				if (!data.FileAttributes.HasFlag(FileAttributes.ReparsePoint))
					return LinkType.HardLink;

				switch (data.Reserved0)
				{
					case Win32Constants.IO_REPARSE_TAG_SYMLINK:
						return LinkType.Symbolic;

					case Win32Constants.IO_REPARSE_TAG_MOUNT_POINT:
						return LinkType.Junction;
				}
			}
			return LinkType.Unknown;
		}

		public virtual string GetTarget(string path)
		{
			var type = GetLinkType(path);

			Type typeBuffer;
			switch (type)
			{
				case LinkType.Junction:
					typeBuffer = typeof(ReparseData<JunctionHeader>);
					break;

				case LinkType.Symbolic:
					typeBuffer = typeof(ReparseData<SymbolicHeader>);
					break;

				default:
					throw new ArgumentException("The path is not a junction or symbolic link.", "path");
			}

			using (var hFile = OpenReparsePoint(path, AccessRights.GenericRead))
			{
				var headerSize = Marshal.SizeOf(typeBuffer);
				var outBufferSize = headerSize;
				var outBuffer = Marshal.AllocHGlobal(outBufferSize);

				try
				{
					var count = 0;
					while (++count <= 2)
					{
						int bytesReturned;
						var b = NativeMethods.DeviceIoControl(
							hFile,
							Win32Constants.FSCTL_GET_REPARSE_POINT,
							IntPtr.Zero,
							0,
							outBuffer,
							outBufferSize,
							out bytesReturned,
							IntPtr.Zero);
						if (b) break;

						var error = Marshal.GetLastWin32Error();
						switch (error)
						{
							case Win32Constants.ERROR_NOT_A_REPARSE_POINT:
								return null;

							case Win32Constants.ERROR_INSUFFICIENT_BUFFER:
								var initialBuffer = (IReparseData)Marshal.PtrToStructure(outBuffer, typeBuffer);
								Marshal.FreeHGlobal(outBuffer);
								outBufferSize = headerSize + initialBuffer.DataBuffer.PrintNameLength + initialBuffer.DataBuffer.SubstituteNameLength;
								outBuffer = Marshal.AllocHGlobal(outBufferSize);
								break;

							default:
								ThrowLastWin32Error(error, "Unable to get information about reparse point.");
								break;
						}
					}

					var reparseDataBuffer = (IReparseData)Marshal.PtrToStructure(outBuffer, typeBuffer);
					switch (reparseDataBuffer.ReparseTag)
					{
						case Win32Constants.IO_REPARSE_TAG_SYMLINK:
						case Win32Constants.IO_REPARSE_TAG_MOUNT_POINT:
							break;

						default:
							throw new InvalidOperationException(String.Format(
								"A reparse point for {0} was expected, instead {1:X} was encountered.",
								type, reparseDataBuffer.ReparseTag));
					}

					if (reparseDataBuffer.DataBuffer.PrintNameLength <= 0)
						throw new IOException("The target link could not be determined.");

					var pathBuffer = outBuffer + headerSize;
					var offset = pathBuffer + reparseDataBuffer.DataBuffer.PrintNameOffset;
					var printName = Marshal.PtrToStringUni(offset, reparseDataBuffer.DataBuffer.PrintNameLength / 2);

					return printName;
				}
				finally
				{
					Marshal.FreeHGlobal(outBuffer);
				}
			}
		}

		public virtual void CreateLink(string path, string target, LinkType type)
		{
			switch (type)
			{
				case LinkType.HardLink:
					CreateHardLink(path, target);
					break;

				case LinkType.Junction:
					CreateJunction(path, target);
					break;

				case LinkType.Symbolic:
					CreateSymbolic(path, target);
					break;

				default:
					throw new ArgumentException(String.Format("Invalid LinkType {0} was specified.", type), "type");
			}
		}

		protected virtual void CreateHardLink(string path, string target)
		{
			NativeMethods.CreateHardLink(target, path, IntPtr.Zero);
		}

		public virtual void CreateJunction(string path, string target)
		{
			path = Path.GetFullPath(path);

			WIN32_FIND_DATA data;
			using (var handle = NativeMethods.FindFirstFile(path, out data))
			{
				if (!handle.IsInvalid)
					throw new IOException("A file or folder already exists with the same name as the junction.");
			}

			Directory.CreateDirectory(path);

			var encoding = Encoding.Unicode;
			var nullChar = new byte[] { 0, 0 };

			var printName = Path.GetFullPath(target).Replace(Win32Constants.NonInterpretedPathPrefix, String.Empty);
			while (printName.EndsWith("\\"))
				printName = printName.Remove(printName.Length - 1);
			var printNameBytes = encoding.GetBytes(printName);
			var printNameLength = printNameBytes.Length;

			var substituteName = Win32Constants.NonInterpretedPathPrefix + printName + "\\";
			var substituteNameBytes = encoding.GetBytes(substituteName);
			var substituteNameLength = substituteNameBytes.Length;

			using (var hJunction = OpenReparsePoint(path, AccessRights.GenericWrite))
			{
				var junctionHeader = new JunctionHeader
				{
					SubstituteNameOffset = 0,
					SubstituteNameLength = checked((ushort)substituteNameLength),

					PrintNameOffset = checked((ushort)(substituteNameLength + nullChar.Length)),
					PrintNameLength = checked((ushort)printNameLength),
				};

				var junctionLength = Marshal.SizeOf(junctionHeader) + nullChar.Length * 2;
				var reparseLength = junctionLength + junctionHeader.SubstituteNameLength + junctionHeader.PrintNameLength;

				var reparseHeader = new ReparseHeader
				{
					ReparseTag = Win32Constants.IO_REPARSE_TAG_MOUNT_POINT,
					ReparseDataLength = checked((ushort)(reparseLength)),
					Reserved = 0,
				};

				var bufferLength = Marshal.SizeOf(reparseHeader) + reparseHeader.ReparseDataLength;
				using (var buffer = SafeLocalAllocHandle.Allocate(bufferLength))
				{
					var offset = buffer.Write(reparseHeader, 0);
					offset += buffer.Write(junctionHeader, offset);
					offset += buffer.Write(substituteNameBytes, offset);
					offset += buffer.Write(nullChar, offset);
					offset += buffer.Write(printNameBytes, offset);
					offset += buffer.Write(nullChar, offset);

					if (offset != bufferLength)
						throw new Exception();

					int bytesReturned;
					var b = NativeMethods.DeviceIoControl(
						hJunction,
						Win32Constants.FSCTL_SET_REPARSE_POINT,
						buffer,
						bufferLength,
						IntPtr.Zero,
						0,
						out bytesReturned,
						IntPtr.Zero);
					if (!b)
						Marshal.ThrowExceptionForHR(Marshal.GetHRForLastWin32Error());
				}
			}
		}

		protected virtual void CreateSymbolic(string path, string target)
		{
		}

		#endregion

		private static SafeFileHandle OpenReparsePoint(string reparsePoint, AccessRights accessRights)
		{
			var hFile = NativeMethods.CreateFile(
				reparsePoint,
				accessRights,
				FileShareMode.FileShareRead | FileShareMode.FileShareWrite,
				IntPtr.Zero,
				FileCreationDisposition.OpenExisting,
				FileAttributeFlags.FileFlagBackupSemantics | FileAttributeFlags.FileFlagOpenReparsePoint,
				IntPtr.Zero);

			var error = Marshal.GetLastWin32Error();
			if (error != 0)
				ThrowLastWin32Error(error, "Unable to open reparse point.");

			return hFile;
		}

		private static void ThrowLastWin32Error(int error, string message)
		{
			throw new IOException(message, Marshal.GetExceptionForHR(error));
		}

	}
}