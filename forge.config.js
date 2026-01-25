const config = {
  packagerConfig: {
    name: 'Mater',
    icon: './mater',
    ignore: [
      /\.src\.js$/,
      /test/,
      /test-results/,
      /\.md$/,
      /forge\.config\.js/,
      /esbuild\.config\.js/,
      /\.stylelintrc/,
      /playwright\.config\./
    ]
  },
  makers: [
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin', 'linux', 'win32']
    },
    {
      name: '@electron-forge/maker-dmg',
      config: {
        format: 'ULFO'
      }
    },
    {
      name: '@electron-forge/maker-squirrel',
      config: {}
    }
  ]
}

export default config
