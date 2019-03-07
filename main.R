options(stringsAsFactors = FALSE)

## setup
library(rtweet)
library(neo4r)
library(dplyr)
library(stringr)
library(tidyr)
library(purrr)
library(readr)


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


#################### import the data into neo4j (managed with Neo Desktop)

## set neo home to reference the import folder
NEO_HOME = "/Users/btibert/Library/Application Support/Neo4j Desktop/Application/neo4jDatabases/database-3618b711-1309-42c0-aebc-b5c1ed64a772/installation-3.5.3/"


## connect to the database
graph = neo4j_api$new(url = "http://localhost:7474", 
                      user = "neo4j", 
                      password = "password")
graph$ping()

## create constraints
call_neo4j("CREATE CONSTRAINT ON (n:User) ASSERT n.id IS UNIQUE;", graph)
call_neo4j("CREATE CONSTRAINT ON (n:Tweet) ASSERT n.id IS UNIQUE;", graph)
call_neo4j("CREATE CONSTRAINT ON (n:Hashtag) ASSERT n.name IS UNIQUE;", graph)


## write tweets to imports
tweets = rt %>% select(user_id, status_id, text, created_at)
FPATH = paste0(NEO_HOME, "import/tweets.csv")
write_csv(tweets, FPATH)

## write user to imports
FPATH = paste0(NEO_HOME, "import/users.csv")
write_csv(user, FPATH)

## write user to tags and tags to imports
FPATH = paste0(NEO_HOME, "import/tags.csv")
tweet_tags$hashtags_clean = tolower(tweet_tags$hashtags_clean)
write_csv(tweet_tags, FPATH)

## write user to mentions and tags to imports
FPATH = paste0(NEO_HOME, "import/mentions.csv")
write_csv(tweet_mentions, FPATH)

## write user to retweets and tags to imports
FPATH = paste0(NEO_HOME, "import/retweet.csv")
write_csv(tweet_retweet, FPATH)

## write user to retweets and tags to imports
FPATH = paste0(NEO_HOME, "import/quote.csv")
write_csv(tweet_quote, FPATH)

## import the user data
CQL = "
MERGE (u:User {id: row.user_id})
ON CREATE SET u += row
"
load_csv(url = "file:///users.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")


## import the tweet data
CQL = "
MERGE (t:Tweet {id: row.status_id})
ON CREATE SET t += row
"
load_csv(url = "file:///tweets.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")


## import the tag data
CQL = "
MERGE (t:Tweet {id: row.status_id})
MERGE (h:Hashtag {name: row.hashtags_clean})
CREATE (t)-[:HASHTAG]->(h)
"
load_csv(url = "file:///tags.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")


## import the mentions data
CQL = "
MERGE (t:Tweet {id: row.status_id})
MERGE (u:User {id: row.mentions_user_id})
CREATE (t)-[:MENTIONED]->(u)
"
load_csv(url = "file:///mentions.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")


## import the retweet data
CQL = "
MERGE (t:Tweet {id: row.status_id})
MERGE (r:Tweet {id: row.retweet_status_id})
CREATE (t)-[:RETWEET_OF]->(r)
"
load_csv(url = "file:///retweet.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")


## import the quote data
CQL = "
MERGE (t:Tweet {id: row.status_id})
MERGE (q:Tweet {id: row.quoted_status_id})
CREATE (t)-[:QUOTED]->(q)
"
load_csv(url = "file:///quote.csv", 
         on_load = CQL, 
         con = graph, 
         periodic_commit = 1000, 
         as = "row")
