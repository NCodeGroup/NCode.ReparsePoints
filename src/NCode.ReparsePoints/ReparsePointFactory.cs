namespace NCode.ReparsePoints
{
	/// <summary>
	/// Factory methods to create the default implementation of <see cref="IReparsePointProvider"/>.
	/// </summary>
	public static class ReparsePointFactory
	{
		private static IReparsePointProvider _provider;

		/// <summary>
		/// Instantiates the default implementation of <see cref="IReparsePointProvider"/>.
		/// </summary>
		public static IReparsePointProvider Create()
		{
			return new ReparsePointProvider();
		}

		/// <summary>
		/// Singleton instance for the default implementation of <see cref="IReparsePointProvider"/>.
		/// </summary>
		public static IReparsePointProvider Provider
		{
			get { return _provider ?? (_provider = Create()); }
			set { _provider = value; }
		}

	}
}