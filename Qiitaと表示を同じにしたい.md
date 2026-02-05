# Qiita 上の表示となるべく同じにしたい

note    : Qiita 形式
message : ZENN 形式

info（デフォルト）：一般的な情報
warn：警告
alert：強い警告
question：質問や疑問

参考：<https://trap.jp/post/1791/>

## やってみた

:::note info

- やったね
:::

:::note warn

- 困ったね
:::

:::note alert

- あかん
:::

:::note question

- なんで？
:::

<!-- markdownlint-disable MD033 -->
<details><summary>.crossnote/style.less</summary>
<!-- markdownlint-enable MD033 -->

```less:style.less
/* Please visit the URL below for more information: */
/*   https://shd101wyy.github.io/markdown-preview-enhanced/#/customize-css */

.markdown-preview.markdown-preview {
  // modify your style here
  // eg: background-color: blue;

  .alert {
    padding: 15px;
    margin-bottom: 20px;
    border: 1px solid transparent;
    border-radius: 4px;
    display: block;
    width: auto;
  }
  .alert > p,
  .alert > ul {
    margin-bottom: 0;
  }
  .alert-danger {
    color: #a94442;
    background-color: #f2dede;
    border-color: #ebccd1;
  }

  .alert-success {
    color: #3c763d;
    background-color: #dff0d8;
    border-color: #d6e9c6;
  }

  .alert-info {
    color: #31708f;
    background-color: #d9edf7;
    border-color: #bce8f1;
  }

  .alert-warning {
    color: #8a6d3b;
    background-color: #fcf8e3;
    border-color: #faebcc;
  }
}
```

</details>
<!-- markdownlint-disable MD033 -->
<details><summary>.crossnote/parser.js</summary>
<!-- markdownlint-enable MD033 -->

```js:parser.js
({
  onWillParseMarkdown: async function (markdown) {

    markdown = markdown.replace(/:::note info[\s\S]*?:::/gm, (success_alert) => {
      success_alert =
        '<div class="alert alert-success">\n' + success_alert.slice(12);
      success_alert = success_alert.slice(0, -3) + "</div>";
      return success_alert;
    });

    markdown = markdown.replace(/:::note warn[\s\S]*?:::/gm, (warning_alert) => {
      warning_alert =
        '<div class="alert alert-warning">\n' + warning_alert.slice(12);
      warning_alert = warning_alert.slice(0, -3) + "</div>";
      return warning_alert;
    });

    markdown = markdown.replace(/:::note alert[\s\S]*?:::/gm, (danger_alert) => {
      danger_alert =
        '<div class="alert alert-danger">\n' + danger_alert.slice(13);
      danger_alert = danger_alert.slice(0, -3) + "</div>";
      return danger_alert;
    });

    markdown = markdown.replace(/:::note question[\s\S]*?:::/gm, (info_alert) => {
      info_alert = '<div class="alert alert-info">\n' + info_alert.slice(16);
      info_alert = info_alert.slice(0, -3) + "</div>";
      return info_alert;
    });

    return markdown;
  },

  onDidParseMarkdown: async function (html) {
    return html;
  },

  onWillTransformMarkdown: async function (markdown) {
    return markdown;
  },

  onDidTransformMarkdown: async function (markdown) {
    return markdown;
  },

  processWikiLink: function ({ text, link }) {
    return {
      text,
      link: link ? link : text.endsWith(".md") ? text : `${text}.md`,
    };
  },
});
```

</details>
