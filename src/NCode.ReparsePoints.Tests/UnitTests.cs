using System;
using System.ComponentModel;
using System.IO;
using NUnit.Framework;

namespace NCode.ReparsePoints.Tests
{
	[TestFixture]
	public class UnitTests
	{
		[Test]
		public void Junction()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);

				if (Directory.Exists(expectedSource))
					Directory.Delete(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Junction);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Junction, link.Type);
				Assert.AreEqual(LinkType.Junction, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		[ExpectedException(typeof(InvalidOperationException))]
		public void JunctionExistsFile()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);
				File.WriteAllText(expectedSource, String.Empty);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Junction);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Junction, link.Type);
				Assert.AreEqual(LinkType.Junction, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		[ExpectedException(typeof(InvalidOperationException))]
		public void JunctionExistsDir()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);
				Directory.CreateDirectory(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Junction);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Junction, link.Type);
				Assert.AreEqual(LinkType.Junction, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		public void SymbolicDir()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);

				if (Directory.Exists(expectedSource))
					Directory.Delete(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void SymbolicDirExistsFile()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);
				File.WriteAllText(expectedSource, String.Empty);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void SymbolicDirExistsDir()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				Directory.CreateDirectory(expectedTarget);
				Directory.CreateDirectory(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (Directory.Exists(expectedTarget)) Directory.Delete(expectedTarget, true);
			}
		}

		[Test]
		public void SymbolicFile()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);

				if (File.Exists(expectedSource))
					File.Delete(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedTarget)) File.Delete(expectedTarget);
			}
		}

		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void SymbolicFileExistsFile()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);
				File.WriteAllText(expectedSource, String.Empty);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedTarget)) File.Delete(expectedTarget);
			}
		}

		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void SymbolicFileExistsDir()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);
				Directory.CreateDirectory(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.Symbolic);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.Symbolic, link.Type);
				Assert.AreEqual(LinkType.Symbolic, provider.GetLinkType(expectedSource));
				Assert.AreEqual(expectedTarget, link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedSource)) File.Delete(expectedTarget);
			}
		}

		[Test]
		public void HardLink()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);

				if (File.Exists(expectedSource))
					File.Delete(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.HardLink);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.HardLink, link.Type);
				Assert.AreEqual(LinkType.HardLink, provider.GetLinkType(expectedSource));
				Assert.IsNull(link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedTarget)) File.Delete(expectedTarget);
			}
		}

		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void HardLinkExistsFile()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);
				File.WriteAllText(expectedSource, String.Empty);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.HardLink);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.HardLink, link.Type);
				Assert.AreEqual(LinkType.HardLink, provider.GetLinkType(expectedSource));
				Assert.IsNull(link.Target);
			}
			finally
			{
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedTarget)) File.Delete(expectedTarget);
			}
		}


		[Test]
		[ExpectedException(typeof(Win32Exception))]
		public void HardLinkExistsDir()
		{
			var context = TestContext.CurrentContext;
			var expectedSource = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			var expectedTarget = Path.Combine(context.WorkDirectory, Guid.NewGuid().ToString("N"));
			try
			{
				File.WriteAllText(expectedTarget, String.Empty);
				Directory.CreateDirectory(expectedSource);

				var provider = ReparsePointFactory.Create();
				provider.CreateLink(expectedSource, expectedTarget, LinkType.HardLink);

				var link = provider.GetLink(expectedSource);
				Assert.IsNotNull(link);
				Assert.AreEqual(LinkType.HardLink, link.Type);
				Assert.AreEqual(LinkType.HardLink, provider.GetLinkType(expectedSource));
				Assert.IsNull(link.Target);
			}
			finally
			{
				if (Directory.Exists(expectedSource)) Directory.Delete(expectedSource, true);
				if (File.Exists(expectedSource)) File.Delete(expectedSource);
				if (File.Exists(expectedTarget)) File.Delete(expectedTarget);
			}
		}

	}
}