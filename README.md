# EX603-Ride-Sharing-Database

1. Project title and one-line summary — what system you modelled, in a sentence.
2. The domain — your theme and the questions the platform must answer. Two to three paragraphs.
3. Schema — embed the ERD image; summarize the five roles and your key design decisions.
4. Query catalogue — per unit, a short table listing the queries and the business question each answers, linked to the .sql files.
5. Technical highlights — three to five things a reader should notice.
6. What I would do differently — an honest paragraph. Critiquing your own work is a senior signal, not a weakness.
7. Video presentation — embed or link the video.
8. How to run it — the commands to create the schema and execute a query. Assume the reader has a database and nothing else.

#### The five roles
#### Role    |    What it is                                  |                                   Always has
#### actor   |    The user who acts on the platform.                                        |     A primary key and a display name. 
#### producer |   The supply-side entity being acted upon.                                  |     A primary key, a display name, an activity flag, and a     ####                                                                                       |         numeric attribute used for filtering. 
#### event     |  The high-volume fact table recording each action.                         |     Foreign keys to actor and producer, a timestamp, and a                                                                                               |      numeric metric you will aggregate. 
#### catalog  |   A descriptive dimension: the tags or categories that classify producers. |      A primary key and a name. 
#### junction |   The many-to-many link between producer and catalog.                    |        A composite primary key over foreign keys to producer and                                                                                                  catalog. 

