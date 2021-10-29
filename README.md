# BSModChecker

GitHubに存在するBeat SaberのMODをなんかいい感じにするやつです。

WidnwosPowerShell(PowerShell 5)とPowerShell 7で動作確認しました。

## 使い方

このファイルと同じディレクトリに `modList.txt` を作成しURLを改行区切りで記入します。

`start.bat` を実行するとPowerShellの画面が出てきますがしばらく待つとGUIが表示されます。

OpenRepoは単純にリストにあるURLを開きます。

DownloadAssetは最新リリースのファイルをダウンロードします。ダウンロード先は同じディレクトリのDownloadsです。

Installはダウンロードしたファイルの展開まで行います。今の所展開先は同じディレクトリのtempです。展開されたら適当にコピーなりしてください。そのうち指定したディレクトリに展開できるようにするかも

## APIリミット

未認証だとリクエスト上限が厳しいので `credential.txt` に `{username}:{token}` と記入しておくことで指定したアカウント情報を使用することができます。  
詳しい手順は以下のリンクを参照。作成の際に権限を付与する必要はありません。  
[https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
