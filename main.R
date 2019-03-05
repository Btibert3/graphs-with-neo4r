options(stringsAsFactors = FALSE)

## setup
library(rtweet)
library(neo4r)
library(dplyr)
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
                   n = 18000,
                   include_rts = TRUE)
dim(rt)
glimpse(rt)


############### parse the data before the import into neo4j
