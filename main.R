options(stringsAsFactors = FALSE)

## setup
library(rtweet)
library(neo4r)
library(dplyr)
library(stringr)
library(tidyr)
library(purrr)


## auth into twitter
token = create_token(
  app = "BrockTest",
  consumer_key = Sys.getenv("RTWEET_CONSUMER_KEY"),
  consumer_secret = Sys.getenv("RTWEET_CONSUMER_SECRET"),
  access_token = Sys.getenv("RTWEET_ACCESS_TOKEN"),
  access_secret = Sys.getenv("RTWEET_ACCESS_SECRET"))

# create_token(
#   app = "BrockTest",
#   consumer_key = Sys.getenv("RTWEET_CONSUMER_KEY"),
#   consumer_secret = Sys.getenv("RTWEET_CONSUMER_SECRET"))

## get the data in a dataframe
TAGS = "#rstats OR #r4ds OR #neo4j"
rt = search_tweets(q = TAGS,
                   n = 100,
                   include_rts = TRUE)
dim(rt)
glimpse(rt)
saveRDS(rt, "data/tweets.rds")


## learnings: even though text contains #rstats, hashtag didnt show in list


############### parse the data before the import into neo4j

######## hashtags -- twitter api is missing hashtags, even though they are part of search
## extract manually into a list column and make a long dataframe with tweet id and tags
## https://stackoverflow.com/questions/13762868/how-do-i-extract-hashtags-from-tweets-in-r
TAG_REGEX = "#\\S+"
tweets = rt %>%  mutate(hashtags_clean = str_extract_all(text, TAG_REGEX))
tweet_tags = tweets %>% 
  select(status_id, hashtags_clean) %>% 
  unnest(hashtags_clean)


######## mentions 
tweet_mentions = rt %>% 
  select(status_id, 
         mentions_user_id, 
         mentions_screen_name) %>% 
  unnest() %>% 
  drop_na()


######## tweet is retweet of user 
tweet_retweet = rt %>% 
  filter(is_retweet) %>% 
  select(status_id, 
         retweet_status_id, 
         retweet_user_id, 
         retweet_screen_name)


######## tweet quotes another tweet
tweet_quote = rt %>% 
  filter(is_quote) %>% 
  select(status_id, 
         quoted_status_id, 
         quoted_user_id, 
         quoted_screen_name)



######## user info
user = rt %>% 
  select(user_id, 
         screen_name,
         account_created_at,
         statuses_count,
         favourites_count,
         followers_count,
         followers_count)




