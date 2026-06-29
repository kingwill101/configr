// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Configr',
  tagline: 'Declarative configuration management for local and remote systems',

  url: 'https://kingwill101.github.io',
  baseUrl: '/configr/',

  organizationName: 'kingwill101',
  projectName: 'configr',

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          path: 'docs',
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'Configr',
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docs',
            position: 'left',
            label: 'Docs',
          },
          {
            href: 'https://github.com/kingwill101/configr',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {label: 'Getting Started', to: '/getting-started/tutorial'},
              {label: 'Blocks', to: '/blocks/file'},
              {label: 'Remote Execution', to: '/guides/remote-execution'},
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Configr.`,
      },
      prism: {
        additionalLanguages: ['bash', 'dart', 'json', 'lua', 'yaml'],
      },
    }),
};

module.exports = config;
