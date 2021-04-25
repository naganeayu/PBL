#docker run -e PASSWORD={パスワード} -p 8787:8787 -d ando6oid/neo-mecab
#install.packages ("RMeCab", repos = "http://rmecab.jp/R", type = "source")
#install.packages("wordcloud")
library(RMeCab)
library(dplyr)
library(ggplot2)
library(wordcloud)

src <- "1.txt"
freq <- RMeCabFreq(src)

#品詞
hinshi <- unique(freq$Info1)

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
