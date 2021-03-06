
library(dplyr)         # For data manipulation
library(ggplot2)       # For plotting
library(hrbrthemes)    # For ggplot2 theme. Install with devtools::install_github("hrbrmstr/hrbrthemes")
library(knitr)
library(pdftools)      # For reading text from pdf files
library(rvest)         # For scraping html text
library(tidyr)         # For data cleaning
library(tidytext)      # For data cleaning of text corpus
library(wordcloud)     # For... wordclouds
library(XML)           # For easily reading HTML Tables
##
# Getting & Reading in HTML Letters
urls_77_97 <- paste('http://www.berkshirehathaway.com/letters/', seq(1977, 1997), '.html', sep='')
html_urls <- c(urls_77_97,
               'http://www.berkshirehathaway.com/letters/1998htm.html',
               'http://www.berkshirehathaway.com/letters/1999htm.html',
               'http://www.berkshirehathaway.com/2000ar/2000letter.html',
               'http://www.berkshirehathaway.com/2001ar/2001letter.html')

letters_html <- lapply(html_urls, function(x) read_html(x) %>% html_text())

# Getting & Reading in PDF Letters
urls_03_16 <- paste('http://www.berkshirehathaway.com/letters/', seq(2003, 2016), 'ltr.pdf', sep = '')
pdf_urls <- data.frame('year' = seq(2002, 2016),
                       'link' = c('http://www.berkshirehathaway.com/letters/2002pdf.pdf', urls_03_16))

download_pdfs <- function(x) {
  myfile = paste0(x['year'], '.pdf')
  download.file(url = x['link'], destfile = myfile, mode = 'wb')
  return(myfile)
}

pdfs <- apply(pdf_urls, 1, download_pdfs)
letters_pdf <- lapply(pdfs, function(x) pdf_text(x) %>% paste(collapse=" "))
tmp <- lapply(pdfs, function(x) if(file.exists(x)) file.remove(x)) # Clean up directory

# Combine all letters in a data frame
letters <- do.call(rbind, Map(data.frame, year=seq(1977, 2016), text=c(letters_html, letters_pdf)))
letters$text <- as.character(letters$text)




################################################################################
################################# Tidy Letters #################################
################################################################################

# Tidy letters
tidy_letters <- letters %>% 
  unnest_tokens(word, text) %>%                           # split text into words
  anti_join(stop_words, by = "word") %>%                  # remove stop words
  filter(!grepl('[0-9]', word)) %>%                       # remove numbers
  left_join(get_sentiments("bing"), by = "word") %>%      # add sentiment scores to words
  group_by(year) %>% 
  mutate(linenumber = row_number(),                       # add line numbers
         sentiment = ifelse(is.na(sentiment), 'neutral', sentiment)) %>%
  ungroup




################################################################################
################################# Get S&P Data ################################# --
################################################################################

# Get Historical S&P500 Returns
sp500 <- readHTMLTable('http://pages.stern.nyu.edu/~adamodar/New_Home_Page/datafile/histretSP.html',
                       header = T, which = 1, skip = c(1, seq(92,101))) %>%
         select(1, 2) %>%
         `colnames<-`(c("year", "return")) %>%
         mutate(return = as.numeric(strsplit(as.character(return), split = '%')) / 100)


# Calculate sentiment score by letter
letters_sentiment <- tidy_letters %>%  
  count(year, sentiment) %>%
  spread(key = sentiment, value = n) %>%
  mutate(sentiment_pct = (positive - negative) / (positive + negative + neutral)) %>%
  select(year, sentiment_pct)


ggplot(letters_sentiment, aes(x = year, y = sentiment_pct)) + 
  geom_bar(aes(fill = sentiment_pct < 0), stat = 'identity') + 
  geom_text(aes(label = year, hjust = ifelse(sentiment_pct >= 0, -0.15, 1.15)), vjust = 0.5) +
  scale_fill_manual(guide = F, values = c('#565b63', '#c40909')) +
  scale_x_reverse(name = '') +
  scale_y_percent(limits = c(-0.015, 0.045), breaks = c(-0.01, 0, 0.01, 0.02, 0.03, 0.04)) +
  coord_flip() +
  labs(y='Net Sentiment Ratio',
       title='Text Sentiment of Berkshire Hathaway Letters to Shareholders',
       subtitle='Negative sentiment is strongly associated with recession years',
       caption='michaeltoth.me') + 
  theme_ipsum(grid="X") +
  theme(axis.text.y=element_blank(),
        axis.ticks.y=element_blank())



bing_word_counts <- tidy_letters %>%
  count(word, sentiment, sort = TRUE) %>%
  ungroup()

top_sentiments <- bing_word_counts %>%
  filter(sentiment != 'neutral') %>%
  group_by(sentiment) %>%
  top_n(12, wt = n) %>%
  mutate(n = ifelse(sentiment == "negative", -n, n)) %>%
  mutate(word = reorder(word, n))



ggplot(top_sentiments, aes(x = word, y = n, fill = sentiment)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(guide = F, values = c("#af8dc3", "#7fbf7b")) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(y = "Number of Occurrences",
       x = '',
       title = 'Text Sentiment of Berkshire Hathaway Letters to Shareholders',
       subtitle = 'Most Common Positive and Negative Words',
       caption='michaeltoth.me') +
  theme_ipsum(grid="Y") +
  theme(axis.text.x=element_text(angle = 60, hjust = 1))



tidy_letters %>%
  filter(sentiment != 'neutral') %>%
  count(word, sentiment, sort = TRUE) %>%
  reshape2::acast(word ~ sentiment, value.var = "n", fill = 0) %>% # Needed because acast returns a matrix, which comparison.cloud uses
  comparison.cloud(colors = c("#af8dc3", "#7fbf7b"), max.words = 400)


#####################################################################################################
#####################################################################################################
#####################################################################################################


require(tidyverse)
require(tidytext)
require(RColorBrewer)
require(gplots)
theme_set(theme_bw(12))
#Descriptive Statistics
#Analysis steps of emotion terms in textual data included word tokenization, 
#pre-processing of tokens to exclude stop words and numbers and then invoking the 
#get_sentiment function using the Tidy package, followed by aggregation and presentation
#of results. Word tokenization is the process of separating text into single words or unigrams.



#Emotion words frequency and proportions

total_words_count <- letters %>%
    unnest_tokens(word, text) %>%  
    anti_join(stop_words, by = "word") %>%                  
    filter(!grepl('[0-9]', word)) %>%
   left_join(get_sentiments("nrc"), by = "word") %>%                        
    group_by(year) %>%
    summarize(total= n()) %>%
    ungroup()

emotion_words_count <- letters %>% 
  unnest_tokens(word, text) %>%                           
  anti_join(stop_words, by = "word") %>%                  
  filter(!grepl('[0-9]', word)) %>%
  left_join(get_sentiments("nrc"), by = "word") %>%
  filter(!(sentiment == "negative" | sentiment == "positive" | sentiment == "NA")) %>%
  group_by(year) %>%
  summarize(emotions= n()) %>%
  ungroup()

emotions_to_total_words <- total_words_count %>%
     left_join(emotion_words_count, by="year") %>%
               mutate(percent_emotions=round((emotions/total)*100,1))

ggplot(emotions_to_total_words, aes(x=year, y=percent_emotions)) +
     geom_line(size=1) +
     scale_y_continuous(limits = c(0, 35), breaks = c(0, 5, 10, 15, 20, 25, 30, 35)) +
     xlab("Year") + 
     ylab("Emotion terms / total words (%)") + theme(legend.position="none") +
     ggtitle("Proportion of emotion words usage \n in Mr. Buffett's annual shareholder letters")




#Depicting distribution of emotion words usage

### pull emotion words and aggregate by year and emotion terms

emotions <- letters %>% 
  unnest_tokens(word, text) %>%                           
  anti_join(stop_words, by = "word") %>%                  
  filter(!grepl('[0-9]', word)) %>%
  left_join(get_sentiments("nrc"), by = "word") %>%
  filter(!(sentiment == "negative" | sentiment == "positive")) %>%
  group_by(year, sentiment) %>%
  summarize( freq = n()) %>%
  mutate(percent=round(freq/sum(freq)*100)) %>%
  select(-freq) %>%
  ungroup()
### need to convert the data structure to a wide format
emo_box = emotions %>%
spread(sentiment, percent, fill=0) %>%
ungroup()
### color scheme for the box plots (This step is optional)
cols  <- colorRampPalette(brewer.pal(7, "Set3"), alpha=TRUE)(8)
boxplot(emo_box[,c(2:9)], col=cols, lty=1, shrink=0.8, textcolor="red", 
       xlab="Emotion Terms", ylab="Emotion words count (%)",
       main="Distribution of emotion words count in annual shareholder letters (1978 - 2016)")



#Emotion words usage over time

## yearly line chart
ggplot(emotions, aes(x=year, y=percent, color=sentiment, group=sentiment)) +
geom_line(size=1) +
geom_point(size=0.5) +
xlab("Year") +
  ylab("Emotion words count (%)") +
  ggtitle("Emotion words expressed in Mr. Buffett's \n annual shareholder letters")



#Average emotion words expression using bar charts with error bars

### calculate overall averages and standard deviations for each emotion term
overall_mean_sd <- emotions %>%
     group_by(sentiment) %>%
     summarize(overall_mean=mean(percent), sd=sd(percent))
### draw a bar graph with error bars
ggplot(overall_mean_sd, aes(x = reorder(sentiment, -overall_mean), y=overall_mean)) +
     geom_bar(stat="identity", fill="darkgreen", alpha=0.7) + 
     geom_errorbar(aes(ymin=overall_mean-sd, ymax=overall_mean+sd), 
     width=0.2,position=position_dodge(.9)) +
     xlab("Emotion Terms") +
     ylab("Emotion words count (%)") +
     ggtitle("Emotion words expressed in Mr. Buffett's \n annual shareholder letters (1977 � 2016)") + 
     theme(axis.text.x=element_text(angle=45, hjust=1)) +
     coord_flip( )




#Emotion terms usage over time compared to 40-years averages

## Hi / Low plots compared to the 40-years average
emotions_diff <- emotions  %>%
     left_join(overall_mean_sd, by="sentiment") %>%
     mutate(difference=percent-overall_mean)

ggplot(emotions_diff, aes(x=year, y=difference, colour=difference>0)) +
geom_segment(aes(x=year, xend=year, y=0, yend=difference),
size=1.1, alpha=0.8) +
geom_point(size=1.0) +
xlab("Emotion Terms") +
     ylab("Net emotion words count (%)") +
     ggtitle("Emotion words expressed in Mr. Buffett's \n annual shareholder letters (1977 - 2016)") + 
theme(legend.position="none") +
facet_wrap(~sentiment, ncol=4)





