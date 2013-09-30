-- no errors but have to fix soon

-- postgres creates default each time but no errors [[handles drop fine when u remove default]]
-- mysql creates default each time but no errors [[handles drop fine when u remove default]]
-- oracle has no problem and doesnt create it each time [[doesnt handle drop well cos the default always exists even tho value is now null:ALTER TABLE "testlen" MODIFY "txt" DEFAULT NULL]]

{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies, OverloadedStrings #-}
{-# LANGUAGE GADTs, FlexibleContexts #-}
{-# LANGUAGE EmptyDataDecls    #-}
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
module TestODBC where

import Database.Persist
import Database.Persist.ODBC
import Database.Persist.TH
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger
import Data.Text (Text)

import Data.Time (getCurrentTime,UTCTime)

import System.Environment (getArgs)
import Employment
import Data.Conduit
import qualified Data.Conduit.List as CL
import Control.Monad (when,unless)
import qualified Database.HDBC as H
import qualified Database.HDBC.ODBC as H

import FtypeEnum
import qualified Database.Esqueleto as E
import Database.Esqueleto (select,where_,(^.),from,Value(..))

import Data.ByteString (ByteString)
import Data.Ratio
import Text.Blaze.Html

share [mkPersist sqlOnlySettings, mkMigrate "migrateAll", mkDeleteCascade sqlOnlySettings] [persistLowerCase|
Test0 
    mybool Bool
    deriving Show
Test1 
    flag Bool
    flag1 Bool Maybe
    dbl Double 
    db2 Double Maybe
    deriving Show
    
Test2
    dt UTCTime
    deriving Show
    
Persony
    name String
    employment Employment
    deriving Show
    
Personx
    name String Eq Ne Desc
    age Int Lt Asc
    color String Maybe Eq Ne
    PersonxNameKey name
    deriving Show

Testnum
    bar Int
    znork Int Maybe
    znork1 String 
    znork2 String Maybe
    znork3 UTCTime
    name String Maybe
    deriving Show
Foo
    bar String
    deriving Show
Person
    name String
    age Int Maybe
    deriving Show
BlogPost
    title String
    authorId PersonId
    deriving Show

Asm
  name Text
  description Text
  UniqueAsm name
--  deriving Typeable
  deriving Show
  
Xsd
  name Text
  description Text
  asmid AsmId
  UniqueXsd name -- global
--  deriving Typeable
  deriving Show
  
Ftype
  name Text
  UniqueFtype name
--  deriving Typeable
  deriving Show

Line
  name Text
  description Text
  pos Int
  ftypeid FtypeEnum
  xsdid XsdId
  EinzigName xsdid name  -- within an xsd:so can repeat fieldnames in different xsds
  EinzigPos xsdid pos   
--  deriving Typeable
  deriving Show
  

Interface
  name Text
  fname Text
  ftypeid FtypeId
  iname FtypeEnum
  UniqueInterface name
--  deriving Typeable
  deriving Show

Testother json
  bs1 ByteString Maybe
  bs2 ByteString 
  deriving Show

Testrational json
  rat Rational
  deriving Show

Testhtml 
  myhtml Html
  -- deriving Show

Testblob 
  bs1 ByteString Maybe
  deriving Show

Testblob3 
  bs1 ByteString 
  bs2 ByteString 
  bs3 ByteString 
  deriving Show

Testlen
  txt  Text maxlen=5 -- default='xx12'
  str  String maxlen=5
  bs   ByteString maxlen=5
  mtxt Text Maybe maxlen=5
  mstr String Maybe maxlen=5
  mbs  ByteString Maybe maxlen=5
  deriving Show
|]

main :: IO ()
main = do
-- HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\<dsnname>
  [arg] <- getArgs
  let (dbtype,dsn) = 
       case arg of -- odbc system dsn
           "d" -> (DB2,"dsn=db2_test")
           "p" -> (Postgres,"dsn=pg_gbtest")
           "m" -> (MySQL,"dsn=mysql_test")
           "s" -> (MSSQL True,"dsn=mssql_testdb; Trusted_Connection=True") -- mssql 2012 [full limit and offset support]
           "so" -> (MSSQL False,"dsn=mssql_testdb; Trusted_Connection=True") -- mssql pre 2012 [limit support only]
           -- "so" -> (MSSQL False,"dsn=mssql_test2012; Trusted Connection=True") -- use older driver [this is junk]
           "o" -> (Oracle False,"dsn=oracle_testdb") -- pre oracle 12c [no support for limit and offset] 
           "on" -> (Oracle True,"dsn=oracle_testdb") -- >= oracle 12c [full limit and offset support]
           xs -> error $ "unknown option:choose p m s so o on d found[" ++ xs ++ "]"

  runResourceT $ runNoLoggingT $ withODBCConn dbtype dsn $ runSqlConn $ do
    liftIO $ putStrLn "\nbefore migration\n"
    runMigration migrateAll
    liftIO $ putStrLn "after migration"
    case dbtype of 
      MSSQL {} -> do -- deleteCascadeWhere Asm causes seg fault for mssql only
          deleteWhere ([]::[Filter Line])
          deleteWhere ([]::[Filter Xsd])
          deleteWhere ([]::[Filter Asm])
      _ -> do
          deleteCascadeWhere ([]::[Filter Asm])
          deleteCascadeWhere ([]::[Filter Person])

    deleteWhere ([]::[Filter Person])
    deleteWhere ([]::[Filter Persony])
    deleteWhere ([]::[Filter Personx])
    deleteWhere ([]::[Filter Testother])
    deleteWhere ([]::[Filter Testrational])
    deleteWhere ([]::[Filter Testblob])
    deleteWhere ([]::[Filter Testblob3])
    deleteWhere ([]::[Filter Testother])
    deleteWhere ([]::[Filter Testnum])
    deleteWhere ([]::[Filter Testhtml])
    deleteWhere ([]::[Filter Testblob3])
    deleteWhere ([]::[Filter Test1])
    deleteWhere ([]::[Filter Test0])
    deleteWhere ([]::[Filter Testlen])

    when True $ testbase dbtype
 
testbase :: DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()
testbase dbtype = do    
    liftIO $ putStrLn "\n*** in testbase\n"
    a1 <- insert $ Foo "test"
    liftIO $ putStrLn $ "a1=" ++ show a1
    aa <- selectList ([]::[Filter Foo]) []
    liftIO $ putStrLn $ "aa=" ++ show aa
    johnId <- insert $ Person "John Doe" $ Just 35
    liftIO $ putStrLn $ "johnId[" ++ show johnId ++ "]"
    janeId <- insert $ Person "Jane Doe" Nothing
    liftIO $ putStrLn $ "janeId[" ++ show janeId ++ "]"

    aa <- selectList ([]::[Filter Person]) []
    unless (length aa == 2) $ error $ "wrong number of Person rows " ++ show aa

    _ <- insert $ BlogPost "My fr1st p0st" johnId
    _ <- insert $ BlogPost "One more for good measure" johnId
    aa <- selectList ([]::[Filter BlogPost]) []
    unless (length aa == 2) $ error $ "wrong number of BlogPost rows " ++ show aa

    --oneJohnPost <- selectList [BlogPostAuthorId ==. johnId] [LimitTo 1]
    --liftIO $ print (oneJohnPost :: [Entity BlogPost])

    john <- get johnId
    liftIO $ print (john :: Maybe Person)
    dt <- liftIO getCurrentTime
    v1 <- insert $ Testnum 100 Nothing "hello" (Just "world") dt Nothing
    v2 <- insert $ Testnum 100 (Just 222) "dude" Nothing dt (Just "something")
    liftIO $ putStrLn $ "v1=" ++ show v1
    liftIO $ putStrLn $ "v2=" ++ show v2

    aa <- selectList ([]::[Filter Testnum]) []
    unless (length aa == 2) $ error $ "wrong number of Testnum rows " ++ show aa

    delete janeId
    deleteWhere [BlogPostAuthorId ==. johnId]
    test0
    test1 dbtype
    test2 
    test3 
    test4
    test5 dbtype
    test6
    when (limitoffset dbtype) test7
    when (limitoffset dbtype) test8
    case dbtype of
      Oracle { oracle12c=False } -> return ()
      _ -> test9
    test10 dbtype
    test11 dbtype
    test12 dbtype
    
test0::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test0 = do
    liftIO $ putStrLn "\n*** in test0\n"
    pid <- insert $ Personx "Michael" 25 Nothing
    liftIO $ print pid

    p1 <- get pid
    liftIO $ print p1

    replace pid $ Personx "Michael" 26 Nothing
    p2 <- get pid
    liftIO $ print p2

    p3 <- selectList [PersonxName ==. "Michael"] []
    liftIO $ print p3

    _ <- insert $ Personx "Michael2" 27 Nothing
    deleteWhere [PersonxName ==. "Michael2"]
    p4 <- selectList [PersonxAge <. 28] []
    liftIO $ print p4

    update pid [PersonxAge =. 28]
    p5 <- get pid
    liftIO $ print p5

    updateWhere [PersonxName ==. "Michael"] [PersonxAge =. 29]
    p6 <- get pid
    liftIO $ print p6

    _ <- insert $ Personx "Eliezer" 2 $ Just "blue"
    p7 <- selectList [] [Asc PersonxAge]
    liftIO $ print p7

    _ <- insert $ Personx "Abe" 30 $ Just "black"
    p8 <- selectList [PersonxAge <. 30] [Desc PersonxName]
    liftIO $ print p8

    _ <- insert $ Personx "Abe1" 31 $ Just "brown"
    p9 <- selectList [PersonxName ==. "Abe1"] []
    liftIO $ print p9
    
    aa <- selectList ([]::[Filter Personx]) []
    unless (length aa == 4) $ error $ "wrong number of Personx rows " ++ show aa    

    p10 <- getBy $ PersonxNameKey "Michael"
    liftIO $ print p10

    p11 <- selectList [PersonxColor ==. Just "blue"] []
    liftIO $ print p11

    p12 <- selectList [PersonxColor ==. Nothing] []
    liftIO $ print p12

    p13 <- selectList [PersonxColor !=. Nothing] []
    liftIO $ print p13

    delete pid
    plast <- get pid
    liftIO $ print plast

test1::DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()    
test1 dbtype = do
    liftIO $ putStrLn "\n*** in test1\n"
    pid <- insert $ Persony "Dude" Retired
    liftIO $ print pid
    pid <- insert $ Persony "Dude1" Employed
    liftIO $ print pid
    pid <- insert $ Persony "Snoyman aa" Unemployed
    liftIO $ print pid
    pid <- insert $ Persony "bbb Snoyman" Employed
    liftIO $ print pid

    aa <- selectList ([]::[Filter Persony]) []
    unless (length aa == 4) $ error $ "wrong number of Person rows " ++ show aa
    liftIO $ putStrLn $ "persony " ++ show aa
    let sql = case dbtype of 
                Oracle {} -> "SELECT \"name\" FROM \"persony\" WHERE \"name\" LIKE '%Snoyman%'"
                DB2 {} -> "SELECT \"name\" FROM \"persony\" WHERE \"name\" LIKE '%Snoyman%'"
                _  -> "SELECT name FROM persony WHERE name LIKE '%Snoyman%'"
    rawQuery sql [] $$ CL.mapM_ (liftIO . print)
    
test2::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test2 = do
    liftIO $ putStrLn "\n*** in test2\n"
    aaa <- insert $ Test0 False 
    liftIO $ print aaa

    aa <- selectList ([]::[Filter Test0]) []
    unless (length aa == 1) $ error $ "wrong number of Person rows " ++ show aa
        
test3::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test3 = do    
    liftIO $ putStrLn "\n*** in test3\n"
    a1 <- insert $ Test1 True (Just False) 100.3 Nothing
    liftIO $ putStrLn $ "a1=" ++ show a1
    a2 <- insert $ Test1 False Nothing 100.3 (Just 12.44)
    liftIO $ putStrLn $ "a2=" ++ show a2
    a3 <- insert $ Test1 True (Just True) 100.3 (Just 11.11)
    liftIO $ putStrLn $ "a3=" ++ show a3
    a4 <- insert $ Test1 False Nothing 100.3 Nothing
    liftIO $ putStrLn $ "a4=" ++ show a4
    ret <- selectList ([]::[Filter Test1]) [] 
    liftIO $ putStrLn $ "ret=" ++ show ret

    aa <- selectList ([]::[Filter Test1]) []
    unless (length aa == 4) $ error $ "wrong number of Test1 rows " ++ show aa

test4::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test4 = do
    liftIO $ putStrLn "\n*** in test4\n"
    a1 <- insert $ Asm "NewAsm1" "description for newasm1" 

    x11 <- insert $ Xsd "NewXsd11" "description for newxsd11" a1
    l111 <- insert $ Line "NewLine111" "description for newline111" 10 Xsd_string x11
    l112 <- insert $ Line "NewLine112" "description for newline112" 11 Xsd_boolean x11
    l113 <- insert $ Line "NewLine113" "description for newline113" 12 Xsd_decimal x11
    l114 <- insert $ Line "NewLine114" "description for newline114" 15 Xsd_int x11

    x12 <- insert $ Xsd "NewXsd12" "description for newxsd12" a1
    l121 <- insert $ Line "NewLine121" "description for newline1" 12 Xsd_int x12
    l122 <- insert $ Line "NewLine122" "description for newline2" 19 Xsd_boolean x12
    l123 <- insert $ Line "NewLine123" "description for newline3" 13 Xsd_string x12
    l124 <- insert $ Line "NewLine124" "description for newline4" 99 Xsd_double x12
    l125 <- insert $ Line "NewLine125" "description for newline5" 2 Xsd_boolean x12

    a2 <- insert $ Asm "NewAsm2" "description for newasm2" 

    a3 <- insert $ Asm "NewAsm3" "description for newasm3" 
    x31 <- insert $ Xsd "NewXsd31" "description for newxsd311" a3

    aa <- selectList ([]::[Filter Asm]) []
    unless (length aa == 3) $ error $ "wrong number of Asm rows " ++ show aa
    aa <- selectList ([]::[Filter Xsd]) []
    unless (length aa == 3) $ error $ "wrong number of Xsd rows " ++ show aa
    aa <- selectList ([]::[Filter Line]) []
    unless (length aa == 9) $ error $ "wrong number of Line rows " ++ show aa


    [Value mpos] <- select $ 
                       from $ \ln -> do
                          where_ (ln ^. LineXsdid E.==. E.val x11)
                          return $ E.joinV $ E.max_ (E.just (ln ^. LinePos))
    liftIO $ putStrLn $ "mpos=" ++ show mpos                          

test5::DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()
test5 dbtype = do
    liftIO $ putStrLn "\n*** in test5\n"
    a1 <- insert $ Testother (Just "abc") "zzzz" 
    case dbtype of 
      MSSQL {} -> liftIO $ putStrLn $ show dbtype ++ " insert multiple blob fields with a null fails"
      DB2 {} -> liftIO $ putStrLn $ show dbtype ++ " insert multiple blob fields with a null fails"
      _ -> do
              a2 <- insert $ Testother Nothing "aaa" 
              liftIO $ putStrLn $ "a2=" ++ show a2
    a3 <- insert $ Testother (Just "nnn") "bbb" 
    a4 <- insert $ Testother (Just "ddd") "mmm" 
    xs <- case dbtype of 
            Oracle {} -> selectList ([]::[Filter Testother]) [] -- cannot sort blobs in oracle
            DB2 {} -> selectList ([]::[Filter Testother]) [] -- cannot sort blobs in db2?
            _ -> selectList [] [Desc TestotherBs1] 
    liftIO $ putStrLn $ "xs=" ++ show xs
    case dbtype of 
      Oracle {} -> return ()
      DB2 {} -> return ()
      _ -> do
              ys <- selectList [] [Desc TestotherBs2] 
              liftIO $ putStrLn $ "ys=" ++ show ys
    
    aa <- selectList ([]::[Filter Testother]) []
    case dbtype of
      MSSQL {} -> unless (length aa == 3) $ error $ show dbtype ++ " :wrong number of Testother rows " ++ show aa
      DB2 {} -> unless (length aa == 3) $ error $ show dbtype ++ " :wrong number of Testother rows " ++ show aa
      _ -> unless (length aa == 4) $ error $ "wrong number of Testother rows " ++ show aa
      
    
test6::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test6  = do
    liftIO $ putStrLn "\n*** in test6\n"
    r1 <- insert $ Testrational (4%6)
    r2 <- insert $ Testrational (13 % 14)
    liftIO $ putStrLn $ "r1=" ++ show r1
    liftIO $ putStrLn $ "r2=" ++ show r2
    zs <- selectList [] [Desc TestrationalRat] 
    liftIO $ putStrLn $ "zs=" ++ show zs
    h1 <- insert $ Testhtml $ preEscapedToMarkup ("<p>hello</p>"::String)
    liftIO $ putStrLn $ "h1=" ++ show h1

    aa <- selectList ([]::[Filter Testrational]) []
    unless (length aa == 2) $ error $ "wrong number of Testrational rows " ++ show aa

    aa <- selectList ([]::[Filter Testhtml]) []
    unless (length aa == 1) $ error $ "wrong number of Testhtml rows " 
    
test7::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test7 = do
    liftIO $ putStrLn "\n*** in test7\n"
    xs <- selectList [] [Desc LinePos, LimitTo 2, OffsetBy 3] 
    liftIO $ putStrLn $ show (length xs) ++ " rows: limit=2,offset=3 xs=" ++ show xs
    xs <- selectList [] [Desc LinePos, LimitTo 2] 
    liftIO $ putStrLn $ show (length xs) ++ " rows: limit=2 xs=" ++ show xs
    xs <- selectList [] [Desc LinePos, OffsetBy 3] 
    liftIO $ putStrLn $ show (length xs) ++ " rows: offset=3 xs=" ++ show xs

test8::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test8 = do
    liftIO $ putStrLn "\n*** in test8\n"
    xs <- select $ 
             from $ \ln -> do
                where_ (ln ^. LinePos E.>=. E.val 0)
                E.orderBy [E.asc (ln ^. LinePos)]
                E.limit 2
                E.offset 3
                return ln
    liftIO $ putStrLn $ show (length xs) ++ " rows: limit=2 offset=3 xs=" ++ show xs

test9::SqlPersistT (NoLoggingT (ResourceT IO)) ()
test9 = do
    liftIO $ putStrLn "\n*** in test9\n"
    xs <- selectList [] [Desc LinePos, LimitTo 2] 
    liftIO $ putStrLn $ show (length xs) ++ " rows: limit=2,offset=0 xs=" ++ show xs
    xs <- selectList [] [Desc LinePos, LimitTo 4] 
    liftIO $ putStrLn $ show (length xs) ++ " rows: limit=4,offset=0 xs=" ++ show xs

test10::DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()
test10 dbtype = do
    liftIO $ putStrLn "\n*** in test10\n"
    a1 <- insert $ Testblob3 "abc1" "def1" "zzzz1" 
    a2 <- insert $ Testblob3 "abc2" "def2" "test2" 
    case dbtype of 
      Oracle {} -> liftIO $ putStrLn "skipping insert empty string into oracle blob column (treated as a null)"
        {-
        *** Exception: SqlError {seState = "[\"HY000\"]", seNativeError = -1, 
        seErrorMsg = "execute execute: [\"1400: [Oracle][ODBC][Ora]ORA-01400: cannot insert NULL into (\\\"SYSTEM\\\".\\\"testblob3\\\".\\\"bs1\\\")\\n\"]"}
        -}
      _ -> do
             a3 <- insert $ Testblob3 "" "hello3" "world3" 
             return ()
    ys <- selectList ([]::[Filter Testblob3]) [] 
    liftIO $ putStrLn $ "ys=" ++ show ys

    aa <- selectList ([]::[Filter Testblob3]) []
    case dbtype of
      Oracle {} -> unless (length aa == 2) $ error $ show dbtype ++ " :wrong number of Testblob3 rows " ++ show aa
      _ -> unless (length aa == 3) $ error $ "wrong number of Testblob3 rows " ++ show aa

test11::DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()
test11 dbtype = do
    liftIO $ putStrLn "\n*** in test11\n"
    case dbtype of 
       MSSQL {} -> liftIO $ putStrLn $ show dbtype ++ ":inserting null in a blob not supported so skipping"
       DB2 {} -> liftIO $ putStrLn $ show dbtype ++ ":inserting null in a blob not supported so skipping"
       _ -> do
              _ <- insert $ Testblob Nothing  
              return ()
    _ <- insert $ Testblob $ Just "some data for testing"
    _ <- insert $ Testblob $ Just "world"
    liftIO $ putStrLn "after testblob inserts"

    xs <- selectList ([]::[Filter Testblob]) [] -- mssql fails if there is a null in a blog column
    liftIO $ putStrLn $ "testblob xs=" ++ show xs

    aa <- selectList ([]::[Filter Testblob]) []
    case dbtype of
      MSSQL {} -> unless (length aa == 2) $ error $ show dbtype ++ " :wrong number of Testblob rows " ++ show aa
      DB2 {} -> unless (length aa == 2) $ error $ show dbtype ++ " :wrong number of Testblob rows " ++ show aa
      _ -> unless (length aa == 3) $ error $ "wrong number of Testblob rows " ++ show aa

test12::DBType -> SqlPersistT (NoLoggingT (ResourceT IO)) ()
test12 dbtype = do
    liftIO $ putStrLn "\n*** in test12\n"
    a1 <- insert $ Testlen "txt1" "str1" "bs1" (Just "txt1m") (Just "str1m") (Just "bs1m")     
    a2 <- insert $ Testlen "txt2" "str2" "bs2" (Just "aaaa") (Just "str2m") (Just "bs2m")     

    aa <- selectList ([]::[Filter Testlen]) []
    case dbtype of
      -- Oracle {} -> unless (length aa == 2) $ error $ show dbtype ++ " :wrong number of Testlen rows " ++ show aa
      _ -> unless (length aa == 2) $ error $ "wrong number of Testlen rows " ++ show aa

    liftIO $ putStrLn $ "aa=" ++ show aa

limitoffset :: DBType -> Bool
limitoffset dbtype = 
  case dbtype of 
    Oracle False -> False
    MSSQL False -> False
    _ -> True
    
main2::IO ()
main2 = do
--  let connectionString = "dsn=mssql_testdb; Trusted_Connection=True"
  let connectionString = "dsn=db2_test"
  conn <- H.connectODBC connectionString
  putStrLn "\n1\n"
  stmt1 <- H.prepare conn "select * from test93"
  putStrLn "\n2\n"
  results <- H.fetchAllRowsAL stmt1
  putStrLn "\n3\n"
  mapM_ print results
  putStrLn "\n4\n"

  putStrLn "\na\n"
  --stmt1 <- H.prepare conn "create table test93 (bs1 blob)"
  --putStrLn "\nb\n"
  --vals <- H.execute stmt1 [] 
  --putStrLn "\nc\n"
  stmt1 <- H.prepare conn "insert into test93 values(blob(?))"
  putStrLn "\nd\n"
  vals <- H.execute stmt1 [H.SqlByteString "hello world"] 
  putStrLn "\ne\n"
  _ <- H.commit conn 
  error "we are done!!"

  
--  a <- H.quickQuery' conn "select * from testblob" []  -- hangs here in both mssql drivers [not all the time]
--  putStrLn $ "\n5\n"
--  print a

  stmt <- H.prepare conn "insert into testblob (bs1) values(?)" 
  putStrLn "\n6\n"
  vals <- H.execute stmt [H.SqlNull] 
  putStrLn "\n7\n"
  vals <- H.execute stmt [H.SqlNull] 
  putStrLn "\n8\n"
  vals <- H.execute stmt [H.SqlNull] 
  putStrLn "\n9\n"
  
  results <- H.fetchAllRowsAL stmt1
  mapM_ print results
  putStrLn "\nTESTBLOB worked\n"

  --stmt <- H.prepare conn "insert into testother (bs1,bs2) values(convert(varbinary(max),?),convert(varbinary(max),?))" 
  stmt <- H.prepare conn "insert into testother (bs1,bs2) values(convert(varbinary(max), cast (? as varchar(100))),convert(varbinary(max), cast (? as varchar(100))))"
  vals <- H.execute stmt [H.SqlByteString "hello",H.SqlByteString "test"] 

  --vals <- H.execute stmt [H.SqlNull,H.SqlByteString "test"] 
  putStrLn "\nTESTOTHER worked\n"

  H.commit conn
  print vals
        
