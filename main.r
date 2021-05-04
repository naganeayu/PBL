#docker run -e PASSWORD={パスワード} -p 8787:8787 -d ando6oid/neo-mecab
#install.packages ("RMeCab", repos = "http://rmecab.jp/R", type = "source")
#install.packages("wordcloud")
#install.packages("igraph", dependencies = TRUE)
library(RMeCab)
library(dplyr)
library(ggplot2)
library(wordcloud)
library(igraph)

#ファイルを一つにまとめる
text1 <- scan("a.txt", what = character(), sep = "\n", blank.lines.skip = T)
text2 <- scan("b.txt", what = character(), sep = "\n", blank.lines.skip = T)
text3 <- scan("c.txt", what = character(), sep = "\n", blank.lines.skip = T)

alltext <- paste(text1, text2, text3)

src <- "1.txt"

#ファイルに上書き
write(alltext, src, append=F)

freq <- RMeCabFreq(src)

#品詞
hinshi <- unique(freq$Info1)

#not.inを利用して、不要な品詞を指定する
"%not.in%" <- Negate("%in%")
freq2 <- subset(freq, Info1 %not.in% c("フィラー", "助詞", "感動詞","接続詞","記号", "接頭詞", "副詞", "助動詞"))
freq3 <- subset(freq2, Info2 %not.in% c("固有名詞","非自立","代名詞","接尾","数"))

#不要な文字の削除
freq4 <- subset(freq3, Term %not.in% c("する","ある","その","なる"))

#ソート
sorted <- freq4[order(freq4$Freq, decreasing = T),]

#出現頻度のグラフ
sorted %>%
  filter(Freq >=6) %>%
  mutate(Term=reorder(Term, Freq)) %>%
  ggplot(aes(Term,Freq)) +
  geom_col() +
  theme_gray (base_family = "IPAMincho") +
  coord_flip()

#ワードクラウド
wordcloud(freq4$Term, freq4$Freq, min.freq=4, color=brewer.pal(8, "Dark2"), family="IPAMincho")

######################################################
#共起ネットワーク
######################################################

#前処理
text <- scan("1.txt", what = character(), blank.lines.skip = T)
text <- gsub("[[:blank:]]","",text)# 全角半角空白とタブ削除
text <- gsub("ジョブディスクリプション","ジョブデスクリプション",text)
text <- gsub("デイリースタンドアップ","デイリー・スタンドアップ",text)
text <- gsub("コンピュータサイエンス","コンピュータ・サイエンス",text)
text <- gsub("チームグループ","チーム・グループ",text)
write(text, "amended.txt", append=F)

#共起語の集計
#NgramResult <- NgramDF("amended.txt", type=1, N=2, pos=c("名詞", "動詞", "形容詞", "副詞"))
NgramResult <- docDF("amended.txt", type=1, N=2, pos=c("名詞", "形容詞"), nDF=1)

#品詞細分類のパターン
#NgramResult %>% use_series(POS2) %>% unique()

#品詞細分類が「数」は「接尾」「非自立」ではない要素を取り出す
NgramResult2 <- NgramResult %>% select(everything(),
                            FREQ = amended.txt) %>% filter(!grepl("数|接尾|非自立",
                                                            POS2))%>% filter(!grepl("A|B|C", N1))%>% filter(!grepl("A|B|C", N2))

#共起頻度3以上のペアのみを抽出
#NgramResult_pair <- subset(NgramResult, Freq>2)

#頻度10以上のみ
NgramResult3 <- NgramResult2 %>% filter(FREQ > 9)

#ネットワークの描画
g <- graph.data.frame(NgramResult3, directed=FALSE)

plot(g, vertex.color="orange", vertex.size=3,
     vertex.label.cex=1, #形態素のサイズ
     vertex.label.dist=.8, #ラベルを円から離す
     edge.width=E(g)$weight,#エッジのサイズを調整する
     vertex.label.family="JP1")

#コミュニティ
com <- edge.betweenness.community(g, weights=E(g)$weight, directed=FALSE)
plot(com, g, vertex.size=3,
     vertex.label.cex=1, #形態素のサイズ
     vertex.label.dist=.8, #ラベルを円から離す
     edge.width=E(g)$weight,#エッジのサイズを調整する
     vertex.label.family="JP1")