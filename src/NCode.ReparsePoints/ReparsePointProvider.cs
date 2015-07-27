using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
using NCode.ReparsePoints.Win32;

namespace NCode.ReparsePoints
{
	/// <summary>
	/// Contains the methods to create and inspect win32 file and folder reparse
	/// points such as hard links, soft links (aka junctions), and symbolic links.
	/// </summary>
	/// <remarks>
	/// Technically speaking, hard links are not reparse points but this library
	/// supports them too.
	/// </remarks>
	public interface IReparsePointProvider
	{
		/// <summary>
		/// Given a path, determines the type of reparse point.
		/// </summary>
		/// <param name="path">The path to inspect.</param>
		/// <returns>A <see cref="LinkType"/> enumeration.</returns>
		LinkType GetLinkType(string path);

		/// <summary>
		/// Given a path, returns the information about a reparse point.
		/// </summary>
		/// <param name="path">The path to inspect.</param>
		/// <returns>A <see cref="ReparseLink"/> that contains the information
		/// about a reparse point.</returns>
		ReparseLink GetLink(string path);

		/// <summary>
		/// Creates a new reparse point such as a hard link, junction (aka soft
		/// link), or symoblic link.
		/// </summary>
		/// <param name="path">The path of reparse point to create.</param>
		/// <param name="target">The target for the reparse point.</param>
		/// <param name="type">A <see cref="LinkType"/> enumeration that specifies
		/// the type of reparse point to create.</param>
		void CreateLink(string path, string target, LinkType type);
	}

	internal class ReparsePointProvider : IReparsePointProvider
	{
		#region IReparsePointProvider Members

		public virtual LinkType GetLinkType(string path)
		{
			Win32FindData data;
			using (var handle = NativeMethods.FindFirstFile(path, out data))
			{
				if (handle.IsInvalid)
					return LinkType.Unknown;

				if (!data.FileAttributes.HasFlag(FileAttributes.ReparsePoint))
				{
					return data.FileAttributes.HasFlag(FileAttributes.Directory)
						? LinkType.Unknown
						: LinkType.HardLink;
				}

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

		public virtual ReparseLink GetLink(string path)
		{
			var attributes = File.GetAttributes(path);
			var link = new ReparseLink
			{
				Attributes = attributes
			};

			if (!attributes.HasFlag(FileAttributes.ReparsePoint))
			{
				link.Type = attributes.HasFlag(FileAttributes.Directory)
					? LinkType.Unknown
					: LinkType.HardLink;

				return link;
			}

			var encoding = Encoding.Unicode;
			var reparseHeaderSize = Marshal.SizeOf(typeof(ReparseHeader));
			var bufferLength = reparseHeaderSize + 2048;

			using (var hReparsePoint = OpenReparsePoint(path, AccessRights.GenericRead))
			{
				int error;
				do
				{
					using (var buffer = SafeLocalAllocHandle.Allocate(bufferLength))
					{
						int bytesReturned;
						var b = NativeMethods.DeviceIoControl(
							hReparsePoint,
							Win32Constants.FSCTL_GET_REPARSE_POINT,
							SafeLocalAllocHandle.InvalidHandle,
							0,
							buffer,
							bufferLength,
							out bytesReturned,
							IntPtr.Zero);
						error = Marshal.GetLastWin32Error();

						if (b)
						{
							var reparseHeader = buffer.Read<ReparseHeader>(0);

							IReparseData data;
							switch (reparseHeader.ReparseTag)
							{
								case Win32Constants.IO_REPARSE_TAG_MOUNT_POINT:
									data = buffer.Read<JunctionData>(reparseHeaderSize);
									link.Type = LinkType.Junction;
									break;

								case Win32Constants.IO_REPARSE_TAG_SYMLINK:
									data = buffer.Read<SymbolicData>(reparseHeaderSize);
									link.Type = LinkType.Symbolic;
									break;

								default:
									throw new InvalidOperationException(String.Format(
										"An unknown reparse tag {0:X} was encountered.",
										reparseHeader.ReparseTag));
							}

							var offset = Marshal.SizeOf(data) + reparseHeaderSize;
							var target = buffer.ReadString(offset + data.SubstituteNameOffset, data.SubstituteNameLength, encoding);

							link.Target = ParseDosDevicePath(target);
							return link;
						}

						if (error == Win32Constants.ERROR_INSUFFICIENT_BUFFER)
						{
							var reparseHeader = buffer.Read<ReparseHeader>(0);
							bufferLength = reparseHeader.ReparseDataLength;
						}
						else
						{
							throw new Win32Exception(error);
						}
					}
				}
				while (error == Win32Constants.ERROR_INSUFFICIENT_BUFFER);
			}
			return link;
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
					CreateSymbolicLink(path, target);
					break;

				default:
					throw new ArgumentException(String.Format("Invalid Type {0} was specified.", type), "type");
			}
		}

		public virtual void CreateHardLink(string file, string target)
		{
			if (!NativeMethods.CreateHardLink(file, target, IntPtr.Zero))
				throw new Win32Exception();
		}

		public virtual void CreateSymbolicLink(string path, string target)
		{
			var attributes = File.GetAttributes(target);
			var flags = attributes.HasFlag(FileAttributes.Directory)
				? SymbolicLinkFlag.Directory
				: SymbolicLinkFlag.File;

			if (!NativeMethods.CreateSymbolicLink(path, target, flags))
				throw new Win32Exception();
		}

		public virtual void CreateJunction(string path, string target)
		{
			path = Path.GetFullPath(path);
			target = Path.GetFullPath(target);

			Win32FindData data;
			using (var handle = NativeMethods.FindFirstFile(path, out data))
			{
				if (!handle.IsInvalid)
					throw new InvalidOperationException("A file or folder already exists with the same name as the junction.");
			}

			Directory.CreateDirectory(path);

			var encoding = Encoding.Unicode;
			var nullChar = new byte[] { 0, 0 };

			var printName = ParseDosDevicePath(target);
			var printNameBytes = encoding.GetBytes(printName);
			var printNameLength = printNameBytes.Length;

			var substituteName = FormatDosDevicePath(printName, false);
			var substituteNameBytes = encoding.GetBytes(substituteName);
			var substituteNameLength = substituteNameBytes.Length;

			var junction = new JunctionData
			{
				SubstituteNameOffset = 0,
				SubstituteNameLength = checked((ushort)substituteNameLength),
				PrintNameOffset = checked((ushort)(substituteNameLength + nullChar.Length)),
				PrintNameLength = checked((ushort)printNameLength)
			};

			var junctionLength = Marshal.SizeOf(junction) + nullChar.Length * 2;
			var reparseLength = junctionLength + junction.SubstituteNameLength + junction.PrintNameLength;

			var reparse = new ReparseHeader
			{
				ReparseTag = Win32Constants.IO_REPARSE_TAG_MOUNT_POINT,
				ReparseDataLength = checked((ushort)(reparseLength)),
				Reserved = 0,
			};

			var bufferLength = Marshal.SizeOf(reparse) + reparse.ReparseDataLength;

			using (var hReparsePoint = OpenReparsePoint(path, AccessRights.GenericWrite))
			using (var buffer = SafeLocalAllocHandle.Allocate(bufferLength))
			{
				var offset = buffer.Write(0, reparse);
				offset += buffer.Write(offset, junction);
				offset += buffer.Write(offset, substituteNameBytes, 0, substituteNameBytes.Length);
				offset += buffer.Write(offset, nullChar, 0, nullChar.Length);
				offset += buffer.Write(offset, printNameBytes, 0, printNameBytes.Length);
				offset += buffer.Write(offset, nullChar, 0, nullChar.Length);
				Debug.Assert(offset == bufferLength);

				int bytesReturned;
				var b = NativeMethods.DeviceIoControl(
					hReparsePoint,
					Win32Constants.FSCTL_SET_REPARSE_POINT,
					buffer,
					bufferLength,
					SafeLocalAllocHandle.InvalidHandle,
					0,
					out bytesReturned,
					IntPtr.Zero);

				if (!b) throw new Win32Exception();
			}
		}

		#endregion

		private static string FormatDosDevicePath(string path, bool sanitize)
		{
			if (sanitize)
				path = ParseDosDevicePath(path);

			return Win32Constants.NonInterpretedPathPrefix + path + "\\";
		}

		private static string ParseDosDevicePath(string path)
		{
			var result = Win32Constants
				.DosDevicePrefixes
				.Where(prefix => path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
				.Aggregate(path, (current, prefix) => current.Remove(0, prefix.Length));

			while (result.EndsWith("\\"))
				result = result.Remove(result.Length - 1);

			return result;
		}

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

			if (hFile.IsInvalid)
				throw new Win32Exception();

			return hFile;
		}

	}
}