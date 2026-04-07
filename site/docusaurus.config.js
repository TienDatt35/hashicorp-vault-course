// @ts-check
// Docusaurus config for the HashiCorp Vault Associate (003) course site.

const { themes: prismThemes } = require('prism-react-renderer');

// Update these two when you fork / publish under your own GitHub org.
const ORG_NAME = 'TienDatt35';
const REPO_NAME = 'hashicorp-vault-course';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Khóa học HashiCorp Vault Associate (003)',
  tagline: 'Khóa học miễn phí, thực hành để luyện thi chứng chỉ Vault Associate',
  favicon: 'img/favicon.ico',

  url: `https://${ORG_NAME}.github.io`,
  baseUrl: `/${REPO_NAME}/`,

  organizationName: ORG_NAME,
  projectName: REPO_NAME,
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // Toàn bộ khóa học bằng tiếng Việt. Docusaurus sẽ đặt <html lang="vi">.
  i18n: {
    defaultLocale: 'vi',
    locales: ['vi'],
  },

  // Expose org/repo to client-side widgets (e.g. LabCallout builds Codespaces URLs).
  customFields: {
    githubOrg: ORG_NAME,
    githubRepo: REPO_NAME,
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: `https://github.com/${ORG_NAME}/${REPO_NAME}/edit/main/site/`,
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
        title: 'Vault Associate (003)',
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'courseSidebar',
            position: 'left',
            label: 'Khóa học',
          },
          {
            href: `https://github.com/${ORG_NAME}/${REPO_NAME}`,
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        copyright: `Giấy phép MIT. Xây dựng bằng Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['hcl', 'bash'],
      },
    }),
};

module.exports = config;
