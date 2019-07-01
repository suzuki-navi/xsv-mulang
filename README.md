# xsv-mulang

雑多な複数のスクリプトファイルからなるプロジェクトをシングルバイナリにビルドするためのツール。


## Usage

    $ mulang

カレントディレクトリを基準に `src` ディレクトリにソースファイルを置き、 `mulang` を実行すると
`var/out.sh` を生成する。


## Example

プロジェクトディレクトリを作成。

    $ mkdir project1
    $ cd project1

`src` ディレクトリを作成し、その中に `main.sh` を作成。

    $ mkdir src
    $ echo 'echo Hello' > src/main.sh
    $ cat src/main.sh
    echo Hello

ディレクトリ構成はこれだけ。

    $ ls
    src
    $ ls src
    main.sh

`mulang` を実行。

    $ mulang

`var` ディレクトリができる。

    $ ls
    src var

その中の `out.sh` が生成されたシングルバイナリの実行ファイル。

    $ ./var/out.sh
    Hello

`src` の中に置いた他のファイルは実行時には環境変数 `MULANG_SOURCE_DIR` でアクセスできる。
以下は `data.txt` というファイルを `src` の中に置いて、それを参照する例。

    $ echo 'cat $MULANG_SOURCE_DIR/data.txt' > src/main.sh
    $ echo 'World' > src/data.txt
    $ mulang
    $ ./var/out.sh
    World


## License

This software is released under the MIT License, see LICENSE.txt.

