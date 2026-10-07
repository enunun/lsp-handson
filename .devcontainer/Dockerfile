# miseの公式Debianイメージ．git，curl，CA証明書とmiseを含み，
# PATHに/mise/shims，MISE_DATA_DIRに/miseが設定済み．
FROM jdxcode/mise:2026.9.12-debian

# GHCのビルドとリンクに必要なライブラリ．
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	openssh-client \
	procps \
	jq \
	libatomic1 \
	build-essential \
	libffi-dev \
	libgmp-dev \
	libncurses-dev \
	zlib1g-dev \
	xz-utils \
	&& rm -rf /var/lib/apt/lists/*

# GHCのツール(happyなど)がUTF-8のソースを読めるように，ロケールをUTF-8にする．
ENV LANG=C.UTF-8

# ghcupでGHC，cabal，HLSを入れる．版はCOURSE.mdの決定に合わせる．
ENV GHCUP_INSTALL_BASE_PREFIX=/opt \
	PATH=/opt/.ghcup/bin:/root/.local/bin:$PATH
ARG GHC_VERSION=9.10.3
ARG CABAL_VERSION=3.16.1.0
ARG HLS_VERSION=2.14.0.0
RUN curl --proto '=https' --tlsv1.2 -sSf "https://downloads.haskell.org/~ghcup/$(uname -m)-linux-ghcup" -o /usr/local/bin/ghcup \
	&& chmod +x /usr/local/bin/ghcup \
	&& ghcup install ghc ${GHC_VERSION} --set \
	&& ghcup install cabal ${CABAL_VERSION} --set \
	&& ghcup install hls ${HLS_VERSION} --set \
	&& ghcup gc --cache --tmpdirs

# fourmoluとhlintは，同じGHCでビルドして/usr/local/binに置く．
# パッケージの一覧はcabal.projectのindex-stateと同じ時点にそろえる．
ARG INDEX_STATE=2026-10-06T00:00:00Z
ARG FOURMOLU_VERSION=0.21.0.0
ARG HLINT_VERSION=3.10
# 2つは異なる版のghc-lib-parserに依存するので，別々に入れる．
RUN cabal update hackage.haskell.org,${INDEX_STATE} \
	&& cabal install --installdir=/usr/local/bin --install-method=copy \
	--index-state=${INDEX_STATE} fourmolu-${FOURMOLU_VERSION} \
	&& cabal install --installdir=/usr/local/bin --install-method=copy \
	--index-state=${INDEX_STATE} hlint-${HLINT_VERSION}

# コースで使うライブラリを先にビルドしておく(受講者の最初のビルドが速くなる)．
COPY .devcontainer/deps /tmp/course-deps
RUN cd /tmp/course-deps \
	&& cabal build --only-dependencies --index-state=${INDEX_STATE} \
	&& rm -rf /tmp/course-deps

# ツール(rtk，lefthook，node，pnpm)はmise.tomlのとおりにイメージへ入れる．
WORKDIR /tmp/mise-bootstrap
COPY mise.toml ./
RUN mise trust \
	&& mise ls --current \
	&& mise install --verbose

# rtkのhookを有効化する．
RUN mkdir -p /root/.claude \
	&& rtk init -g --hook-only

# 起動後は，リポジトリのmise.tomlをグローバル設定として読む．
# これにより，/workspacesの外のディレクトリでも同じツールを使える．
# グローバル設定のルートも/workspacesにして，タスクをリポジトリ直下で実行させる
# (未指定だとホームディレクトリで実行される)．
ENV MISE_GLOBAL_CONFIG_FILE=/workspaces/mise.toml \
	MISE_GLOBAL_CONFIG_ROOT=/workspaces \
	MISE_TRUSTED_CONFIG_PATHS=/workspaces

WORKDIR /workspaces
