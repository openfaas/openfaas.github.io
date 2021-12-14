# Video size

ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ./videoplayback.mp4 

# 2110.333333


2110.333333 / 8
2110.333333 / 4
2110.333333 / 2 + 2110.333333 / 8
2110.333333 / 2 + 2110.333333 / 4


263.791666625
527.58333325
1318.958333125
1582.74999975

rm out-*.mp4

$(
ffmpeg  -ss 00:00:10 -i ./videoplayback.mp4 -an -t 2  \
    -y out-1.mp4 &
ffmpeg  -ss 00:00:30 -i ./videoplayback.mp4 -an -t 2  \
    -y out-2.mp4 &
ffmpeg  -ss 00:02:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-3.mp4 &
ffmpeg  -ss 00:05:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-4.mp4 &
ffmpeg  -ss 00:07:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-5.mp4 &
ffmpeg  -ss 00:10:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-6.mp4 &
ffmpeg  -ss 00:15:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-7.mp4 &
ffmpeg  -ss 00:17:44 -i ./videoplayback.mp4 -an -t 2  \
    -y out-8.mp4 &
ffmpeg  -ss 00:20:00 -i ./videoplayback.mp4 -an -t 2  \
    -y out-9.mp4 &
ffmpeg  -ss 00:33:40 -i ./videoplayback.mp4 -an -t 2  \
    -y out-10.mp4 &
)

$(
echo 'file out-1.mp4' > files.txt
echo 'file out-2.mp4' >> files.txt
echo 'file out-3.mp4' >> files.txt
echo 'file out-4.mp4' >> files.txt
echo 'file out-5.mp4' >> files.txt
echo 'file out-6.mp4' >> files.txt
echo 'file out-7.mp4' >> files.txt
echo 'file out-8.mp4' >> files.txt
echo 'file out-9.mp4' >> files.txt
echo 'file out-10.mp4' >> files.txt

ffmpeg -f concat -safe 0 -i files.txt  -vf 'scale=900:540:force_original_aspect_ratio=decrease,pad=900:540:(ow-iw)/2:(oh-ih)/2,setsar=1' -y preview.mp4
)

