using System.IO;
using NUnit.Framework;

namespace NCode.ReparsePoints.Tests
{
	[TestFixture]
	public class UnitTests
	{
		[Test]
		public void Test()
		{
			Directory.CreateDirectory(@"C:\junction.target");

			if (Directory.Exists(@"C:\junction.source"))
				Directory.Delete(@"C:\junction.source");

			var provider = new ReparsePointProvider();
			provider.CreateJunction(@"C:\junction.source", @"C:\junction.target");

			var target = provider.GetTarget(@"C:\junction.source");
			Assert.AreEqual(@"C:\junction.target", target);
		}

	}
}