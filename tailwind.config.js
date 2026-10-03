/** @type {import('tailwindcss').Config} */
module.exports = {
  // Scan all Elm source for class names. After adding new classes, re-run the
  // build (`npm run build:css`) or keep `npm run watch:css` going.
  content: ['./src/**/*.elm'],
  theme: {
    extend: {
      // Palette lifted from the Trailpost design (claude.ai/design).
      colors: {
        page: '#06090c',
        shell: '#0a1014',
        bar: '#0d161b',
        field: '#0f181d',
        card: '#111c22',
        raised: '#141f25',
        tab: '#1d2a31',
        line: '#1e2c33',
        edge: '#24343c',
        rule: '#2a3a42',
        ink: '#e8e2d4',
        soft: '#cfd6d9',
        body: '#b9c3c7',
        muted: '#8b9ba3',
        faint: '#6d7d85',
        gold: '#e3b54c',
        goldhi: '#f3cf74',
        fine: '#c0f3f3',
        leaf: '#7fd05f',
        go: '#3f9a35',
        gohi: '#4bb03f',
        warn: '#f08a7f',
        danger: '#c0453b',
        discord: '#5865f2',
        sell: '#2d7064',
        buy: '#2e4b75',
        r: {
          common: '#9aa3a7',
          uncommon: '#6fc36a',
          rare: '#5aa2e6',
          epic: '#b07ae0',
          legendary: '#e3b54c',
          ethereal: '#e8574f',
        },
      },
      fontFamily: {
        display: ['Alegreya', 'Georgia', 'serif'],
        sans: ['Barlow', 'system-ui', 'sans-serif'],
        cond: ['"Barlow Condensed"', 'Barlow', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
