import type { ElectrobunConfig } from 'electrobun'

export default {
  app: {
    name: 'Mater',
    identifier: 'com.jasonlong.mater',
    version: '3.0.0'
  },
  runtime: {
    exitOnLastWindowClosed: false
  },
  build: {
    bun: {
      entrypoint: 'src/bun/index.ts'
    },
    views: {
      mainview: {
        entrypoint: 'src/mainview/index.ts'
      }
    },
    copy: {
      'src/mainview/index.html': 'views/mainview/index.html',
      'src/mainview/main.css': 'views/mainview/main.css',
      'img/template': 'views/img/template',
      'img/ico': 'views/img/ico',
      'img/png': 'views/img/png',
      wav: 'views/wav'
    },
    mac: {
      bundleCEF: false,
      icons: 'icon.iconset'
    },
    linux: {
      bundleCEF: false,
      icon: 'mater.png'
    },
    win: {
      bundleCEF: false,
      icon: 'mater.ico'
    }
  }
} satisfies ElectrobunConfig
