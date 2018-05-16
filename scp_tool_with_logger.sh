#!/bin/bash
#
#                       _oo0oo_
#                      o8888888o
#                      88" . "88
#                      (| -_- |)
#                      0\  =  /0
#                    ___/`---'\___
#                  .' \\|     |// '.
#                 / \\|||  :  |||// \
#                / _||||| -:- |||||- \
#               |   | \\\  -  /// |   |
#               | \_|  ''\---/''  |_/ |
#               \  .-\__  '-'  ___/-. /
#             ___'. .'  /--.--\  `. .'___
#          ."" '<  `.___\_<|>_/___.' >' "".
#         | | :  `- \`.;`\ _ /`;.`/ - ` : | |
#         \  \ `_.   \_ __\ /__ _/   .-` /  /
#     =====`-.____`.___ \_____/___.-`___.-'=====
#                       `=---='
#
#
#     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#               佛祖保佑         永無BUG
#
#         pictue from:  https://gist.github.com/edokeh/7580064
#
#       usage:
#       1 檢查遠端.end 文件
#       2 將遠端.end .dat取回本地
#
#       如果叫做test.end, 就把test.dat+test.end拿回來
#
#
#       需配置互信
#       於家目錄建立.ssh資料夾，權限為700(可能已經有)
#       cd ~/.ssh
#       ssh-keygen -t rsa (全enter帶過) 生成 id_rsa id_rsa.pub
#
#       將互信電腦中的id_rsa.pub 匯總成一authorized_keys檔
#       com1:
#           cd ~/.ssh
#           cat id_rsa.pub >> authorized_keys
#           ssh com2@com2domain cat .ssh/id_rsa.pub >> ./authorized_keys
#       即於com1 .ssh 產生的可用於互信的authorized_keys檔，複製給com2即可
#       多台電腦亦然

LOG_PATH="./sftp_log.txt"           # log檔名稱路徑
WRITE_LOG=1                         # 是否寫到log檔(1 || 0)
REMOTE_PATH="remote_dir"                   # 遠端要檢查的目錄
LOCAL_PATH="./local_dir"                  # 本端要複製的目錄

OK_EXT=".ok"
DAT_EXT=".dat"

USER="user"
DOMAIN="test.com"
PORT="22"

logger() {
    # 產生過程log

    # 取得date命令輸出
    # 輸出到STDOUT

    color=`logColor $2`

    echo -e "\x1b[1;31m[$(date +'%Y-%m-%d %H:%M:%S')]\x1b[0m \x1b[1;${color}m$1\x1b[0m"
    if [ $WRITE_LOG = 1 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> $LOG_PATH # 若WRITE_LOG輸出到log檔
    fi
}
logColor() {
    # 返回色碼
    case "$1" in
        "success")
            echo "32"
            ;;

        "warn")
            echo "33"
            ;;

        "info")
            echo "36"
            ;;
        "error")
            echo "31"
            ;;
        *)                  # 預設 info
            echo "36"
            ;;
    esac
}
errorLog() {
    # 發生錯誤
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] \x1b[1;31m$1\x1b[0m" >&2              # 輸出到STDERR
    if [ $WRITE_LOG = 1 ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> $LOG_PATH # 若WRITE_LOG輸出到log檔
    fi
    exit 1                                                    # 以錯誤離開
}

#============================================
#               主程式起點                  #
#============================================
if [ -z $1 ]; then                  # 檢查有沒有輸入參數
    errorLog "請輸入ok檔名"
fi
REMOTE_TOKEN="${1}${OK_EXT}"        # 檔名加上 OK_EXT  (.ok)
REMOTE_FILE="${1}${DAT_EXT}"        # 檔名日噗 DAT_EXT (.dat)

logger "scp tool 啟動"              #敲鑼打鼓

# 建查local_path 是否存在，不存在即建立
if [ ! -d $LOCAL_PATH ]; then
    logger "本地儲存資料夾不存在, 嘗試建立"
    if mkdir -p $LOCAL_PATH; then
        logger "建立成功" "success"
    else
        errorLog "建立失敗"
    fi
fi

# 檢查是否可進行ssh 連線
status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT" "$USER"@"$DOMAIN" echo ok 2>&1)
case $status in
    ok) logger "ssh 連線成功" ;;
    *"Permission denied"*) errorLog "ssh 連線失數: permission denied" ;;
    *"Could not resolve hostname"*) errorLog "ssh 連線失數: could not resolve hostname" ;;
    *) errorLog "ssh 連線失數: 其它:  $status" ;;
esac

# 檢查遠端資料夾是否存在
ssh -q -p "$PORT" "$USER"@"$DOMAIN" "test -d $REMOTE_PATH"
if [ $? -eq 0 ]; then
    logger "遠端資料夾: $REMOTE_PATH 存在"
else
    errorLog "遠端資料夾: $REMOTE_PATH 不存在"
fi

# 檢查是否有ok檔
ssh -q -p "$PORT" "$USER"@"$DOMAIN" "test -e $REMOTE_PATH/$REMOTE_TOKEN"
if [ $? -eq 0 ]; then
    logger "遠端檔案: $REMOTE_TOKEN 存在, 準備開始複製: $REMOTE_TOKEN"
else
    logger "遠端檔案: $REMOTE_TOKEN 不存在" "warn"
    exit 0
fi

# 檢查是否真的有dat檔
ssh -q -p "$PORT" "$USER"@"$DOMAIN" "test -e $REMOTE_PATH/$REMOTE_FILE"
if [ $? -eq 0 ]; then
    logger "遠端檔案: $REMOTE_FILE 存在, 準備開始複製: $REMOTE_FILE"
else
    errorLog "遠端檔案: $REMOTE_FILE 不存在"
fi

# 複製目標檔案 (方便檢查成功與否，使用scp)
scp -P "$PORT" "$USER"@"$DOMAIN":"$REMOTE_PATH/$REMOTE_TOKEN" "$LOCAL_PATH"
if [ $? -eq 0 ]; then
    logger "$REMOTE_TOKEN 複製成功" "success"
else
    logger "$REMOTE_TOKEN 複製失敗" "error"
fi

scp -P "$PORT" "$USER"@"$DOMAIN":"$REMOTE_PATH/$REMOTE_FILE" "$LOCAL_PATH"
if [ $? -eq 0 ]; then
    logger "$REMOTE_FILE 複製成功" "success"
else
    logger "$REMOTE_FILE 複製失敗" "error"
fi

logger "程序結束"
