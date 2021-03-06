USE [master]
GO
/****** Object:  Database [u_tekielsk]    Script Date: 20.01.2022 21:01:50 ******/
CREATE DATABASE [u_tekielsk]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'u_tekielsk', FILENAME = N'/var/opt/mssql/data/u_tekielsk.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'u_tekielsk_log', FILENAME = N'/var/opt/mssql/data/u_tekielsk_log.ldf' , SIZE = 66048KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
ALTER DATABASE [u_tekielsk] SET COMPATIBILITY_LEVEL = 150
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [u_tekielsk].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [u_tekielsk] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [u_tekielsk] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [u_tekielsk] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [u_tekielsk] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [u_tekielsk] SET ARITHABORT OFF 
GO
ALTER DATABASE [u_tekielsk] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [u_tekielsk] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [u_tekielsk] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [u_tekielsk] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [u_tekielsk] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [u_tekielsk] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [u_tekielsk] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [u_tekielsk] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [u_tekielsk] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [u_tekielsk] SET  ENABLE_BROKER 
GO
ALTER DATABASE [u_tekielsk] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [u_tekielsk] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [u_tekielsk] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [u_tekielsk] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [u_tekielsk] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [u_tekielsk] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [u_tekielsk] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [u_tekielsk] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [u_tekielsk] SET  MULTI_USER 
GO
ALTER DATABASE [u_tekielsk] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [u_tekielsk] SET DB_CHAINING OFF 
GO
ALTER DATABASE [u_tekielsk] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [u_tekielsk] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [u_tekielsk] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [u_tekielsk] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [u_tekielsk] SET QUERY_STORE = OFF
GO
USE [u_tekielsk]
GO
/****** Object:  UserDefinedFunction [dbo].[Ilosc_Zamowien_Powyzej_Kwoty]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Ilosc_Zamowien_Powyzej_Kwoty]
(
	@id_klienta INT,
	@kwota MONEY
)
RETURNS INT
AS
BEGIN
RETURN (
SELECT COUNT(liczba_zam) FROM
(
SELECT COUNT(DISTINCT z.ID_zamowienia) AS liczba_zam FROM Zamowienia z
INNER JOIN Szczegoly_Zamowien sz ON sz.ID_zamowienia=z.ID_zamowienia
WHERE z.ID_klienta=@id_klienta AND z.id_pracownika IN (SELECT
ID_pracownika FROM Obsluga)
GROUP BY z.ID_zamowienia
HAVING SUM(sz.Ilosc*sz.Cena_jednostkowa)>@kwota
) AS zamowienia
)
END
GO
/****** Object:  UserDefinedFunction [dbo].[Liczba_wolnych_miejsc]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Liczba_wolnych_miejsc]
(
	@data_od DATETIME,
	@data_do DATETIME
)
RETURNS INT
AS
BEGIN
	DECLARE @miejsc_w_restauracji INT = (SELECT SUM(max_liczba_miejsc) FROM Stoliki)
	DECLARE @zajete_miejsca INT = (SELECT SUM(liczba_miejsc) FROM Szczegoly_rezerwacji
	JOIN Rezerwacje ON Rezerwacje.id_rezerwacji = Szczegoly_rezerwacji.id_rezerwacji
	WHERE Rezerwacje.Data_rezerwacji BETWEEN @data_od AND DATEADD(HOUR,3,@data_do))
	RETURN (@miejsc_w_restauracji-@zajete_miejsca)
END
GO
/****** Object:  UserDefinedFunction [dbo].[Nalicz_Rabat_Ind_Jedn]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Nalicz_Rabat_Ind_Jedn]
(
	@id_klienta INT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @id_rabatu INT = (
	SELECT TOP 1 r.ID_rabatu FROM Rabaty r
	INNER JOIN Aktualnie_Przyznane_Rabaty a ON a.ID_rabatu=r.ID_rabatu AND a.ID_klienta=@id_klienta
	INNER JOIN Rabaty_ind_jedn rj ON rj.ID_rabatu=r.ID_rabatu
	WHERE (GETDATE() >= a.data_przyznania AND r.Data_zdjecia IS NULL)
	OR (GETDATE() BETWEEN a.data_przyznania AND a.data_wygasniecia)
	ORDER BY r.wysokosc_rabatu DESC)
	IF @id_rabatu IS NULL
	BEGIN
		RETURN 0
	END
	RETURN (SELECT wysokosc_rabatu FROM Rabaty WHERE id_rabatu = @id_rabatu) 
END
GO
/****** Object:  UserDefinedFunction [dbo].[Nalicz_Rabat_Ind_Staly]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Nalicz_Rabat_Ind_Staly]
(
	@id_klienta INT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @id_rabatu INT = (
		SELECT TOP 1 r.ID_rabatu FROM Rabaty r
		INNER JOIN Aktualnie_Przyznane_Rabaty a ON a.ID_rabatu=r.ID_rabatu AND a.ID_klienta=@id_klienta
		INNER JOIN Rabaty_Ind_Stale rs ON rs.ID_rabatu=r.ID_rabatu
		WHERE (GETDATE() >= a.data_przyznania AND r.Data_zdjecia IS NULL)
		OR (GETDATE() BETWEEN a.data_przyznania AND a.data_wygasniecia)
		ORDER BY r.wysokosc_rabatu DESC)
	IF @id_rabatu IS NULL
	BEGIN
		RETURN 0
	END
	RETURN (SELECT wysokosc_rabatu FROM Rabaty WHERE id_rabatu = @id_rabatu) 
END
GO
/****** Object:  UserDefinedFunction [dbo].[Ostatnie_usuniecie_z_menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Ostatnie_usuniecie_z_menu]
(
	@id_dania INT
)
RETURNS DATE
AS
BEGIN
RETURN (SELECT TOP 1 Data_zdjecia FROM Menu WHERE @id_dania=ID_dania ORDER BY Data_zdjecia DESC)
END
GO
/****** Object:  Table [dbo].[Menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Menu](
	[id_dania] [int] NOT NULL,
	[data_wprowadzenia] [date] NOT NULL,
	[data_zdjecia] [date] NULL,
	[id_pozycji] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_Menu_1] PRIMARY KEY CLUSTERED 
(
	[id_pozycji] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Dania]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Dania](
	[id_dania] [int] IDENTITY(1,1) NOT NULL,
	[nazwa_dania] [varchar](50) NOT NULL,
	[cena_dania] [money] NOT NULL,
	[id_kategorii] [int] NOT NULL,
	[opis_dania] [varchar](255) NULL,
	[dostępna_ilosc] [int] NULL,
 CONSTRAINT [PK_Dania] PRIMARY KEY CLUSTERED 
(
	[id_dania] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[V_Pokaz_menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Pokaz_menu]
AS 
SELECT nazwa_dania,cena_dania,opis_dania FROM Dania 
JOIN Menu ON Menu.id_dania = Dania.id_dania
WHERE GETDATE() BETWEEN Menu.data_wprowadzenia AND Menu.data_zdjecia
GO
/****** Object:  Table [dbo].[Kategorie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Kategorie](
	[id_kategorii] [int] IDENTITY(1,1) NOT NULL,
	[nazwa_kategorii] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Kategorie] PRIMARY KEY CLUSTERED 
(
	[id_kategorii] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[Menu_dnia]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Menu_dnia]
(
	@data DATE
)
RETURNS TABLE
AS
RETURN
(
	SELECT nazwa_dania,cena_dania,opis_dania,nazwa_kategorii,data_wprowadzenia,data_zdjecia,id_pozycji FROM Dania
	JOIN Menu ON Menu.id_dania = Dania.id_dania
	JOIN Kategorie ON Kategorie.id_kategorii = Dania.id_kategorii
	WHERE (Data_zdjecia IS NULL AND Data_wprowadzenia<=@data)
	OR
	(Data_zdjecia IS NOT NULL and @data BETWEEN Data_wprowadzenia AND Data_zdjecia)
)
GO
/****** Object:  Table [dbo].[Szczegoly_zamowien]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Szczegoly_zamowien](
	[id_zamowienia] [int] NOT NULL,
	[id_pozycji] [int] NOT NULL,
	[cena_jednostkowa] [money] NOT NULL,
	[ilosc] [int] NOT NULL,
	[rabat] [float] NULL,
 CONSTRAINT [PK_Szczegoly_zamowien] PRIMARY KEY CLUSTERED 
(
	[id_zamowienia] ASC,
	[id_pozycji] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[V_Cena_za_zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Cena_za_zamowienie]
AS
SELECT id_zamowienia, SUM(cena_jednostkowa * ilosc * (1 - rabat)) AS 'wartosc_zamowienia'
FROM Szczegoly_zamowien
GROUP BY id_zamowienia
GO
/****** Object:  Table [dbo].[Zamowienia]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Zamowienia](
	[id_zamowienia] [int] IDENTITY(1,1) NOT NULL,
	[id_klienta] [int] NOT NULL,
	[data_zamowienia] [datetime] NOT NULL,
	[data_odbioru] [datetime] NOT NULL,
	[czy_na_wynos] [varchar](1) NOT NULL,
	[id_pracownika] [int] NOT NULL,
	[id_rezerwacji] [int] NULL,
	[id_faktury] [int] NOT NULL,
	[status_faktury] [nchar](1) NULL,
 CONSTRAINT [PK_Zamowienia_1] PRIMARY KEY CLUSTERED 
(
	[id_zamowienia] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Faktury]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Faktury](
	[id_faktury] [int] NOT NULL,
	[data_wystawienia] [datetime] NOT NULL,
	[nazwa_firmy] [varchar](50) NULL,
	[NIP] [varchar](10) NULL,
	[ulica] [varchar](50) NULL,
	[kod_pocztowy] [varchar](50) NULL,
	[nazwa_panstwa] [varchar](50) NULL,
	[nazwa_miasta] [varchar](50) NULL,
	[nr_tel] [varchar](9) NULL,
	[email] [varchar](50) NULL,
	[imie] [varchar](50) NULL,
	[nazwisko] [varchar](50) NULL,
 CONSTRAINT [PK_Faktury] PRIMARY KEY CLUSTERED 
(
	[id_faktury] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[V_Faktury]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Faktury]
AS
SELECT Zamowienia.id_klienta, Zamowienia.id_zamowienia, Zamowienia.id_faktury, status_faktury, data_wystawienia, IIF(nazwa_firmy IS NULL, 'brak danych', nazwa_firmy) AS 'nazwa_firmy',
IIF(NIP IS NULL, 'brak danych', NIP) AS 'NIP', IIF(ulica IS NULL, 'brak danych', ulica) AS 'ulica',
IIF(kod_pocztowy IS NULL, 'brak danych', kod_pocztowy) AS 'kod_pocztowy', IIF(nazwa_panstwa IS NULL, 'brak danych', nazwa_panstwa) AS 'nazwa_panstwa',
IIF(nazwa_miasta IS NULL, 'brak danych', nazwa_miasta) AS 'nazwa_miasta', IIF(nr_tel IS NULL, 'brak danych', nr_tel) AS 'nr_tel',
IIF(email IS NULL, 'brak danych', email) AS 'email', IIF(nazwisko IS NULL, 'brak danych', nazwisko) AS 'nazwisko',
IIF(imie IS NULL, 'brak danych', imie) AS 'imie', V_Cena_za_zamowienie.wartosc_zamowienia
FROM Zamowienia
INNER JOIN Faktury ON Zamowienia.id_faktury = Faktury.id_faktury
INNER JOIN V_Cena_za_zamowienie ON V_Cena_za_zamowienie.id_zamowienia = Zamowienia.id_zamowienia
GO
/****** Object:  UserDefinedFunction [dbo].[Faktura_za_pojedyncze_zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Faktura_za_pojedyncze_zamowienie]
( 
 @id_zamowienia int
)
RETURNS TABLE
AS
RETURN
(
 SELECT * FROM V_Faktury WHERE status_faktury = 'J' AND id_zamowienia = @id_zamowienia
)
GO
/****** Object:  UserDefinedFunction [dbo].[Faktura_za_miesiac]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Faktura_za_miesiac]
( 
 @id_klienta INT,
 @miesiac INT,
 @rok INT
)
RETURNS TABLE
AS
RETURN
(
 SELECT Zamowienia.id_klienta, data_wystawienia, IIF(nazwa_firmy IS NULL, 'brak danych', nazwa_firmy) AS 'nazwa_firmy',
    IIF(NIP IS NULL, 'brak danych', NIP) AS 'NIP', IIF(ulica IS NULL, 'brak danych', ulica) AS 'ulica',
    IIF(kod_pocztowy IS NULL, 'brak danych', kod_pocztowy) AS 'kod_pocztowy', IIF(nazwa_panstwa IS NULL, 'brak danych', nazwa_panstwa) AS 'nazwa_panstwa',
    IIF(nazwa_miasta IS NULL, 'brak danych', nazwa_miasta) AS 'nazwa_miasta', IIF(nr_tel IS NULL, 'brak danych', nr_tel) AS 'nr_tel',
    IIF(email IS NULL, 'brak danych', email) AS 'email', IIF(nazwisko IS NULL, 'brak danych', nazwisko) AS 'nazwisko',
    IIF(imie IS NULL, 'brak danych', imie) AS 'imie', SUM(V_Cena_za_zamowienie.wartosc_zamowienia) AS 'całkowita kwota'
    FROM Zamowienia
    INNER JOIN Faktury ON Zamowienia.id_faktury = Faktury.id_faktury
    INNER JOIN V_Cena_za_zamowienie ON V_Cena_za_zamowienie.id_zamowienia = Zamowienia.id_zamowienia
    WHERE id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok AND status_faktury = 'M'
    GROUP BY id_klienta, data_wystawienia, nazwa_firmy, NIP, ulica, kod_pocztowy, nazwa_panstwa, nazwa_miasta, nr_tel, email, nazwisko, imie
)
GO
/****** Object:  UserDefinedFunction [dbo].[Szczegoly_zamowienia]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Szczegoly_zamowienia]
( 
 @id_zamowienia INT
)
RETURNS TABLE
AS
RETURN
(
 SELECT nazwa_dania, nazwa_kategorii, ilosc, CONVERT(DECIMAL(8, 2), (cena_jednostkowa * (1 - rabat) * ilosc)) AS 'cena' FROM zamowienia
INNER JOIN szczegoly_zamowien ON zamowienia.id_zamowienia = szczegoly_zamowien.id_zamowienia
INNER JOIN menu ON menu.id_pozycji = szczegoly_zamowien.id_pozycji
INNER JOIN dania ON menu.id_dania = dania.id_dania
INNER JOIN kategorie ON kategorie.id_kategorii = dania.id_kategorii
WHERE zamowienia.id_zamowienia = @id_zamowienia
)
GO
/****** Object:  UserDefinedFunction [dbo].[Szczegoly_zamowien_klienta_na_okres]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[Szczegoly_zamowien_klienta_na_okres]
( 
 @id_klienta INT,
 @poczatek DATE,
 @koniec DATE
)
RETURNS TABLE
AS
RETURN
(
SELECT zamowienia.id_zamowienia, nazwa_dania, nazwa_kategorii, ilosc, CONVERT(DECIMAL(8, 2), (cena_jednostkowa * (1 - rabat) * ilosc)) AS 'cena' FROM zamowienia
INNER JOIN szczegoly_zamowien ON zamowienia.id_zamowienia = szczegoly_zamowien.id_zamowienia
INNER JOIN menu ON menu.id_pozycji = szczegoly_zamowien.id_pozycji
INNER JOIN dania ON menu.id_dania = dania.id_dania
INNER JOIN kategorie ON kategorie.id_kategorii = dania.id_kategorii
WHERE zamowienia.id_klienta = @id_klienta AND (data_odbioru BETWEEN @poczatek AND @koniec) AND status_faktury = 'M'
)
GO
/****** Object:  UserDefinedFunction [dbo].[Pokaz_Menu_Dnia]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Pokaz_Menu_Dnia]
(
	@data date
)
RETURNS TABLE
AS
RETURN
(
	SELECT ID_pozycji,Data_wprowadzenia,Data_zdjecia,Nazwa_dania,nazwa_kategorii,Cena_dania, Opis_dania FROM dbo.Menu
	INNER JOIN dbo.Dania ON dbo.Menu.ID_dania=dbo.Dania.ID_dania
	INNER JOIN dbo.Kategorie ON Dania.id_kategorii = dbo.Kategorie.ID_kategorii
	WHERE
	(Data_zdjecia IS NULL AND Data_wprowadzenia<=@data)
	OR
	(Data_zdjecia IS NOT NULL and @data BETWEEN Data_wprowadzenia AND Data_zdjecia)
)
GO
/****** Object:  Table [dbo].[Klienci]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Klienci](
	[id_klienta] [int] IDENTITY(1,1) NOT NULL,
	[nr_tel] [varchar](9) NOT NULL,
	[email] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Klienci_1] PRIMARY KEY CLUSTERED 
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[V_Klienci_Wydatki]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Klienci_Wydatki]
AS
SELECT dbo.Klienci.id_klienta,SUM(dbo.Szczegoly_zamowien.ilosc*dbo.Szczegoly_zamowien.cena_jednostkowa) AS laczna_wartosc
FROM dbo.Klienci
JOIN Zamowienia ON Zamowienia.id_klienta = Klienci.id_klienta
JOIN Szczegoly_zamowien ON Szczegoly_zamowien.id_zamowienia = Zamowienia.id_zamowienia
GROUP BY Klienci.id_klienta
GO
/****** Object:  Table [dbo].[Rezerwacje]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rezerwacje](
	[id_rezerwacji] [int] IDENTITY(1,1) NOT NULL,
	[Data_zlozenia] [datetime] NOT NULL,
	[Data_rezerwacji] [datetime] NOT NULL,
	[id_klienta] [int] NOT NULL,
	[czy_firmowa_imienna] [varchar](1) NOT NULL,
 CONSTRAINT [PK_Rezerwacje] PRIMARY KEY CLUSTERED 
(
	[id_rezerwacji] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Stoliki]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stoliki](
	[id_stolika] [int] IDENTITY(1,1) NOT NULL,
	[max_liczba_miejsc] [int] NOT NULL,
	[czy_aktualne] [varchar](1) NOT NULL,
 CONSTRAINT [PK_Stoliki] PRIMARY KEY CLUSTERED 
(
	[id_stolika] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Szczegoly_rezerwacji]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Szczegoly_rezerwacji](
	[id_rezerwacji] [int] NOT NULL,
	[id_stolika] [int] NOT NULL,
	[liczba_miejsc] [int] NOT NULL,
 CONSTRAINT [PK_Szczegoly_rezerwacji] PRIMARY KEY CLUSTERED 
(
	[id_rezerwacji] ASC,
	[id_stolika] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[Rezerwacje_klienta]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Rezerwacje_klienta]
(
	@id_klienta INT
)
RETURNS TABLE
AS
RETURN
(
SELECT r.Data_zlozenia,r.Data_rezerwacji,s.id_stolika,sr.liczba_miejsc
FROM Rezerwacje r 
JOIN Szczegoly_rezerwacji sr ON sr.id_rezerwacji = r.id_rezerwacji
JOIN Stoliki s ON s.id_stolika = sr.id_stolika
WHERE id_klienta = @id_klienta AND r.Data_rezerwacji > GETDATE()
)
GO
/****** Object:  UserDefinedFunction [dbo].[Faktura_za_pojdeyncze_zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Faktura_za_pojdeyncze_zamowienie]
( 
 @id_zamowienia INT
)
RETURNS TABLE
AS
RETURN
(
 SELECT * FROM V_Faktury WHERE status_faktury = 'J' AND id_zamowienia = @id_zamowienia
)
GO
/****** Object:  UserDefinedFunction [dbo].[Szczegoly_faktury_pojedyncze_zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Szczegoly_faktury_pojedyncze_zamowienie]
( 
 @id_zamowienia INT
)
RETURNS TABLE
AS
RETURN
(
 SELECT nazwa_dania, nazwa_kategorii, ilosc, CONVERT(DECIMAL(8, 2), (cena_jednostkowa * (1 - rabat) * ilosc)) AS 'cena' FROM zamowienia
INNER JOIN szczegoly_zamowien ON zamowienia.id_zamowienia = szczegoly_zamowien.id_zamowienia
INNER JOIN menu ON menu.id_pozycji = szczegoly_zamowien.id_pozycji
INNER JOIN dania ON menu.id_dania = dania.id_dania
INNER JOIN kategorie ON kategorie.id_kategorii = dania.id_kategorii
WHERE zamowienia.id_zamowienia = @id_zamowienia
)
GO
/****** Object:  UserDefinedFunction [dbo].[Dania_z_kategorii]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Dania_z_kategorii]
( 
 @nazwa_kategorii VARCHAR(50)
)
RETURNS TABLE
AS
RETURN
(
 SELECT Nazwa_dania,Cena_dania FROM Dania
 JOIN Kategorie ON Kategorie.id_kategorii = Dania.id_kategorii
 WHERE Kategorie.nazwa_kategorii = @nazwa_kategorii
)
GO
/****** Object:  UserDefinedFunction [dbo].[Szczegoly_zamowien_do_faktury_miesiecznej]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Szczegoly_zamowien_do_faktury_miesiecznej]
( 
 @id_klienta INT,
 @miesiac INT,
 @rok INT
)
RETURNS TABLE
AS
RETURN
(
SELECT zamowienia.id_zamowienia, nazwa_dania, nazwa_kategorii, ilosc, CONVERT(DECIMAL(8, 2), (cena_jednostkowa * (1 - rabat) * ilosc)) AS 'cena' FROM zamowienia
INNER JOIN szczegoly_zamowien ON zamowienia.id_zamowienia = szczegoly_zamowien.id_zamowienia
INNER JOIN menu ON menu.id_pozycji = szczegoly_zamowien.id_pozycji
INNER JOIN dania ON menu.id_dania = dania.id_dania
INNER JOIN kategorie ON kategorie.id_kategorii = dania.id_kategorii
WHERE zamowienia.id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok AND status_faktury = 'M'
)
GO
/****** Object:  View [dbo].[V_Owoce_Morza]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Owoce_Morza]
AS
SELECT dbo.Dania.nazwa_dania, dbo.Dania.cena_dania
FROM dbo.Dania 
INNER JOIN dbo.Kategorie ON dbo.Dania.id_kategorii = dbo.Kategorie.id_kategorii
WHERE (dbo.Kategorie.nazwa_kategorii = 'owoce morza')
GO
/****** Object:  View [dbo].[V_Najpopularniejsze_Dania]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Najpopularniejsze_Dania]
AS
SELECT TOP (20) PERCENT dbo.Dania.nazwa_dania, dbo.Dania.cena_dania,
	SUM(dbo.Szczegoly_zamowien.ilosc) AS Liczba_zamowionych_jednostek
FROM dbo.Menu 
INNER JOIN dbo.Dania ON dbo.Menu.ID_dania = dbo.Dania.ID_dania 
INNER JOIN dbo.Szczegoly_zamowien ON dbo.Menu.ID_pozycji = dbo.Szczegoly_zamowien.id_pozycji
INNER JOIN dbo.Zamowienia ON Zamowienia.id_zamowienia = Szczegoly_zamowien.id_zamowienia
WHERE DATEPART(m,data_zamowienia) = DATEPART(m, DATEADD(m, -1, getdate()))
AND DATEPART(yyyy, data_zamowienia) = DATEPART(yyyy, DATEADD(m, -1, getdate()))
GROUP BY dbo.Dania.Nazwa_dania, dbo.Dania.Cena_dania, dbo.Dania.ID_dania
ORDER BY Liczba_zamowionych_jednostek DESC
GO
/****** Object:  Table [dbo].[Aktualnie_przyznane_rabaty]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Aktualnie_przyznane_rabaty](
	[id_rabatu] [int] NOT NULL,
	[id_klienta] [int] NOT NULL,
	[data_przyznania] [date] NOT NULL,
	[data_wygasniecia] [date] NULL,
 CONSTRAINT [PK_Aktualnie_przyznane_rabaty] PRIMARY KEY CLUSTERED 
(
	[id_rabatu] ASC,
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Rabaty]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rabaty](
	[id_rabatu] [int] IDENTITY(1,1) NOT NULL,
	[wysokosc_rabatu] [float] NOT NULL,
	[data_wprowadzenia] [date] NOT NULL,
	[data_zdjecia] [date] NULL,
 CONSTRAINT [PK_Rabaty] PRIMARY KEY CLUSTERED 
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[Aktualne_rabaty_klienta]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[Aktualne_rabaty_klienta]
(
	@id_klienta INT
)
RETURNS TABLE
AS
RETURN
(
	SELECT ar.data_przyznania,ar.data_wygasniecia,r.wysokosc_rabatu
	FROM Aktualnie_przyznane_rabaty ar
	JOIN Rabaty r ON r.id_rabatu = ar.id_rabatu
	WHERE ar.id_klienta = @id_klienta
)
GO
/****** Object:  View [dbo].[V_Menu_klienta]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Menu_klienta] AS
SELECT nazwa_dania, nazwa_kategorii, cena_dania, opis_dania
FROM Dania
JOIN Menu
ON Menu.id_dania = Dania.id_dania
JOIN Kategorie
ON Dania.id_kategorii = Kategorie.id_kategorii
WHERE dostępna_ilosc > 0
GO
/****** Object:  View [dbo].[V_Klienci_Zamowienia]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Klienci_Zamowienia]
AS
SELECT dbo.Klienci.id_klienta, COUNT(Klienci.id_klienta) AS laczna_wartosc
FROM dbo.Klienci
JOIN Zamowienia ON Zamowienia.id_klienta = Klienci.id_klienta
JOIN Szczegoly_zamowien ON Szczegoly_zamowien.id_zamowienia = Zamowienia.id_zamowienia
GROUP BY Klienci.id_klienta
GO
/****** Object:  Table [dbo].[Klienci_firmy]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Klienci_firmy](
	[id_klienta] [int] NOT NULL,
	[nazwa_firmy] [varchar](50) NOT NULL,
	[NIP] [varchar](10) NOT NULL,
	[ulica] [varchar](50) NOT NULL,
	[kod_pocztowy] [varchar](50) NOT NULL,
	[nazwa_panstwa] [varchar](50) NULL,
	[nazwa_miasta] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Klienci_firmy] PRIMARY KEY CLUSTERED 
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Klienci_ind]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Klienci_ind](
	[id_klienta] [int] NOT NULL,
	[Imie] [varchar](50) NOT NULL,
	[Nazwisko] [varchar](50) NOT NULL,
	[id_firmy] [int] NULL,
 CONSTRAINT [PK_Klienci_ind] PRIMARY KEY CLUSTERED 
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Obsluga]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Obsluga](
	[id_pracownika] [int] IDENTITY(1,1) NOT NULL,
	[imie] [varchar](50) NOT NULL,
	[nazwisko] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Obsluga] PRIMARY KEY CLUSTERED 
(
	[id_pracownika] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Rabaty_ind_jedn]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rabaty_ind_jedn](
	[id_rabatu] [int] NOT NULL,
	[waznosc] [int] NOT NULL,
	[wymagana_kwota] [money] NOT NULL,
 CONSTRAINT [PK_Rabaty_ind_jedn] PRIMARY KEY CLUSTERED 
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Rabaty_ind_stale]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Rabaty_ind_stale](
	[id_rabatu] [int] NOT NULL,
	[liczba_zamowien] [int] NOT NULL,
	[minimalna_kwota] [money] NOT NULL,
 CONSTRAINT [PK_Rabaty_ind_stale] PRIMARY KEY CLUSTERED 
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [IX_Aktualnie_Przyznane_Rabaty]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Aktualnie_Przyznane_Rabaty] ON [dbo].[Aktualnie_przyznane_rabaty]
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Aktualnie_Przyznane_Rabaty_1]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Aktualnie_Przyznane_Rabaty_1] ON [dbo].[Aktualnie_przyznane_rabaty]
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Klienci_Biz]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Klienci_Biz] ON [dbo].[Klienci_firmy]
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Klienci_Ind]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Klienci_Ind] ON [dbo].[Klienci_ind]
(
	[id_klienta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Menu]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Menu] ON [dbo].[Menu]
(
	[id_dania] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Rabaty_Ind_Jednorazowe]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Rabaty_Ind_Jednorazowe] ON [dbo].[Rabaty_ind_jedn]
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Rabaty_Ind_Stale]    Script Date: 20.01.2022 21:01:51 ******/
CREATE NONCLUSTERED INDEX [IX_Rabaty_Ind_Stale] ON [dbo].[Rabaty_ind_stale]
(
	[id_rabatu] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty] ADD  CONSTRAINT [DF_Aktualnie_Przyznane_Rabaty_Data_przyznania]  DEFAULT (getdate()) FOR [data_przyznania]
GO
ALTER TABLE [dbo].[Menu] ADD  CONSTRAINT [DF_Menu_data_zdjecia]  DEFAULT (NULL) FOR [data_zdjecia]
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty]  WITH CHECK ADD  CONSTRAINT [FK_Aktualnie_przyznane_rabaty_Klienci_ind] FOREIGN KEY([id_klienta])
REFERENCES [dbo].[Klienci_ind] ([id_klienta])
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty] CHECK CONSTRAINT [FK_Aktualnie_przyznane_rabaty_Klienci_ind]
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty]  WITH CHECK ADD  CONSTRAINT [FK_Aktualnie_przyznane_rabaty_Rabaty] FOREIGN KEY([id_rabatu])
REFERENCES [dbo].[Rabaty] ([id_rabatu])
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty] CHECK CONSTRAINT [FK_Aktualnie_przyznane_rabaty_Rabaty]
GO
ALTER TABLE [dbo].[Dania]  WITH CHECK ADD  CONSTRAINT [FK_Dania_Kategorie] FOREIGN KEY([id_kategorii])
REFERENCES [dbo].[Kategorie] ([id_kategorii])
GO
ALTER TABLE [dbo].[Dania] CHECK CONSTRAINT [FK_Dania_Kategorie]
GO
ALTER TABLE [dbo].[Klienci_firmy]  WITH CHECK ADD  CONSTRAINT [FK_Klienci_firmy_Klienci1] FOREIGN KEY([id_klienta])
REFERENCES [dbo].[Klienci] ([id_klienta])
GO
ALTER TABLE [dbo].[Klienci_firmy] CHECK CONSTRAINT [FK_Klienci_firmy_Klienci1]
GO
ALTER TABLE [dbo].[Klienci_ind]  WITH CHECK ADD  CONSTRAINT [FK_Klienci_ind_Klienci1] FOREIGN KEY([id_klienta])
REFERENCES [dbo].[Klienci] ([id_klienta])
GO
ALTER TABLE [dbo].[Klienci_ind] CHECK CONSTRAINT [FK_Klienci_ind_Klienci1]
GO
ALTER TABLE [dbo].[Menu]  WITH CHECK ADD  CONSTRAINT [FK_Menu_Dania1] FOREIGN KEY([id_dania])
REFERENCES [dbo].[Dania] ([id_dania])
GO
ALTER TABLE [dbo].[Menu] CHECK CONSTRAINT [FK_Menu_Dania1]
GO
ALTER TABLE [dbo].[Rabaty_ind_jedn]  WITH CHECK ADD  CONSTRAINT [FK_Rabaty_ind_jedn_Rabaty] FOREIGN KEY([id_rabatu])
REFERENCES [dbo].[Rabaty] ([id_rabatu])
GO
ALTER TABLE [dbo].[Rabaty_ind_jedn] CHECK CONSTRAINT [FK_Rabaty_ind_jedn_Rabaty]
GO
ALTER TABLE [dbo].[Rabaty_ind_stale]  WITH CHECK ADD  CONSTRAINT [FK_Rabaty_ind_stale_Rabaty] FOREIGN KEY([id_rabatu])
REFERENCES [dbo].[Rabaty] ([id_rabatu])
GO
ALTER TABLE [dbo].[Rabaty_ind_stale] CHECK CONSTRAINT [FK_Rabaty_ind_stale_Rabaty]
GO
ALTER TABLE [dbo].[Szczegoly_rezerwacji]  WITH CHECK ADD  CONSTRAINT [FK_Szczegoly_rezerwacji_Rezerwacje] FOREIGN KEY([id_rezerwacji])
REFERENCES [dbo].[Rezerwacje] ([id_rezerwacji])
GO
ALTER TABLE [dbo].[Szczegoly_rezerwacji] CHECK CONSTRAINT [FK_Szczegoly_rezerwacji_Rezerwacje]
GO
ALTER TABLE [dbo].[Szczegoly_rezerwacji]  WITH CHECK ADD  CONSTRAINT [FK_Szczegoly_rezerwacji_Stoliki] FOREIGN KEY([id_stolika])
REFERENCES [dbo].[Stoliki] ([id_stolika])
GO
ALTER TABLE [dbo].[Szczegoly_rezerwacji] CHECK CONSTRAINT [FK_Szczegoly_rezerwacji_Stoliki]
GO
ALTER TABLE [dbo].[Szczegoly_zamowien]  WITH CHECK ADD  CONSTRAINT [FK_Szczegoly_zamowien_Menu] FOREIGN KEY([id_pozycji])
REFERENCES [dbo].[Menu] ([id_pozycji])
GO
ALTER TABLE [dbo].[Szczegoly_zamowien] CHECK CONSTRAINT [FK_Szczegoly_zamowien_Menu]
GO
ALTER TABLE [dbo].[Szczegoly_zamowien]  WITH CHECK ADD  CONSTRAINT [FK_Szczegoly_zamowien_Zamowienia1] FOREIGN KEY([id_zamowienia])
REFERENCES [dbo].[Zamowienia] ([id_zamowienia])
GO
ALTER TABLE [dbo].[Szczegoly_zamowien] CHECK CONSTRAINT [FK_Szczegoly_zamowien_Zamowienia1]
GO
ALTER TABLE [dbo].[Zamowienia]  WITH CHECK ADD  CONSTRAINT [FK_Zamowienia_Faktury1] FOREIGN KEY([id_faktury])
REFERENCES [dbo].[Faktury] ([id_faktury])
GO
ALTER TABLE [dbo].[Zamowienia] CHECK CONSTRAINT [FK_Zamowienia_Faktury1]
GO
ALTER TABLE [dbo].[Zamowienia]  WITH CHECK ADD  CONSTRAINT [FK_Zamowienia_Klienci1] FOREIGN KEY([id_klienta])
REFERENCES [dbo].[Klienci] ([id_klienta])
GO
ALTER TABLE [dbo].[Zamowienia] CHECK CONSTRAINT [FK_Zamowienia_Klienci1]
GO
ALTER TABLE [dbo].[Zamowienia]  WITH CHECK ADD  CONSTRAINT [FK_Zamowienia_Obsluga] FOREIGN KEY([id_pracownika])
REFERENCES [dbo].[Obsluga] ([id_pracownika])
GO
ALTER TABLE [dbo].[Zamowienia] CHECK CONSTRAINT [FK_Zamowienia_Obsluga]
GO
ALTER TABLE [dbo].[Zamowienia]  WITH CHECK ADD  CONSTRAINT [FK_Zamowienia_Rezerwacje] FOREIGN KEY([id_rezerwacji])
REFERENCES [dbo].[Rezerwacje] ([id_rezerwacji])
GO
ALTER TABLE [dbo].[Zamowienia] CHECK CONSTRAINT [FK_Zamowienia_Rezerwacje]
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty]  WITH CHECK ADD  CONSTRAINT [CK_Aktualnie_Przyznane_Rabaty_Daty] CHECK  (([Data_przyznania]<=getdate() AND ([Data_wygasniecia] IS NULL OR [Data_wygasniecia]>=[Data_przyznania])))
GO
ALTER TABLE [dbo].[Aktualnie_przyznane_rabaty] CHECK CONSTRAINT [CK_Aktualnie_Przyznane_Rabaty_Daty]
GO
/****** Object:  StoredProcedure [dbo].[Aktualizuj_cene_dania]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Aktualizuj_cene_dania]
	@id_dania INT,
	@nowa_cena MONEY
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @nazwa_dania VARCHAR(50) = (SELECT nazwa_dania FROM Dania WHERE id_dania = @id_dania)
	IF @nazwa_dania IS NULL
	BEGIN 
		;THROW 52000,'Podane danie nie istnieje!',1;
	END
	IF @nowa_cena <= 0
	BEGIN
		;THROW 52000,'Nowa cena musi być liczbą dodatnią!',1;
	END
	BEGIN
	UPDATE Dania SET cena_dania = @nowa_cena WHERE id_dania = @id_dania
	END
END
GO
/****** Object:  StoredProcedure [dbo].[Aktualizuj_Rabat_Ind_Jednorazowy]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Aktualizuj_Rabat_Ind_Jednorazowy]
	@id_klienta INT
AS
BEGIN
SET NOCOUNT ON;
DECLARE @id_rabatu INT =(SELECT r.ID_rabatu FROM Rabaty r
INNER JOIN Rabaty_Ind_Jedn rj ON rj.ID_rabatu=r.ID_rabatu WHERE Data_zdjecia IS NULL)
IF @id_rabatu IS NOT NULL AND NOT EXISTS (SELECT * FROM Aktualnie_Przyznane_Rabaty WHERE
ID_klienta=@id_klienta AND @id_rabatu=ID_rabatu)
BEGIN
DECLARE @laczna_wart_zam MONEY = (SELECT SUM(sz.Ilosc*sz.Cena_jednostkowa) FROM
Szczegoly_Zamowien sz
INNER JOIN Zamowienia z ON z.ID_zamowienia=sz.ID_zamowienia
WHERE @id_klienta=z.ID_klienta)
DECLARE @wymagana_kwota MONEY=(SELECT Wymagana_kwota FROM Rabaty_ind_jedn WHERE
ID_rabatu=@id_rabatu)
IF @laczna_wart_zam>=@wymagana_kwota
BEGIN
EXEC Przyznaj_Rabat_Klientowi
@id_rabatu,
@id_klienta,
NULL,
NULL
END
END
END
GO
/****** Object:  StoredProcedure [dbo].[Aktualizuj_Rabat_Ind_Staly]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Aktualizuj_Rabat_Ind_Staly]
	@id_klienta INT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @id_rabatu INT =(SELECT r.ID_rabatu FROM Rabaty r
	INNER JOIN Rabaty_Ind_Stale ri ON ri.ID_rabatu=r.ID_rabatu
	WHERE Data_zdjecia IS NULL)
	IF @id_rabatu IS NOT NULL AND NOT EXISTS (SELECT * FROM Aktualnie_Przyznane_Rabaty WHERE
	ID_klienta=@id_klienta AND @id_rabatu=ID_rabatu)
	BEGIN
	DECLARE @liczba_zamowien INT = (SELECT Liczba_zamowien FROM Rabaty_Ind_Stale WHERE
	ID_rabatu=@id_rabatu)
	DECLARE @wymagana_kwota MONEY = (SELECT ri.minimalna_kwota FROM Rabaty_ind_stale ri WHERE
	ID_rabatu=@id_rabatu)
	DECLARE @ilosc_powyzej_kwoty INT =(SELECT
	dbo.Ilosc_Zamowien_Powyzej_Kwoty(@id_klienta,@wymagana_kwota))
	IF (@ilosc_powyzej_kwoty>=@liczba_zamowien)
	BEGIN
	EXEC Przyznaj_Rabat_Klientowi
	@id_rabatu,
	@id_klienta,
	NULL,
	NULL
	END
	END
END
GO
/****** Object:  StoredProcedure [dbo].[Anuluj_rezerwacje]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Anuluj_rezerwacje]
	@id_rezerwacji INT
AS
BEGIN
	SET NOCOUNT ON;
	DELETE FROM Szczegoly_Rezerwacji WHERE ID_rezerwacji=@id_rezerwacji
	DELETE FROM Rezerwacje WHERE ID_rezerwacji=@id_rezerwacji
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_danie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_danie]
	@nazwa_dania VARCHAR(50),
	@cena MONEY,
	@nazwa_kategorii VARCHAR(50),
	@opis VARCHAR(255) = NULL,
	@dostepna_ilosc INT /*Ilosc sztuk danego dania jaka restauracja jest w stanie przygotowac w ciagu dnia*/
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN Dodaj_danie
		IF NOT EXISTS(SELECT * FROM Kategorie WHERE nazwa_kategorii = @nazwa_kategorii)
		BEGIN
			INSERT INTO Kategorie VALUES (@nazwa_kategorii)
		END
		DECLARE @id_kategorii INT = (SELECT id_kategorii FROM Kategorie WHERE nazwa_kategorii = @nazwa_kategorii)
		IF @cena <= 0 
		BEGIN
			;THROW 52000,'Cena musi być wartością dodatnią',1;
		END
		IF @dostepna_ilosc <= 0
		BEGIN
			;THROW 52000,'Dostępna ilość musi być wartością dodatnią',1;
		END
		INSERT INTO Dania(nazwa_dania,cena_dania,id_kategorii,opis_dania,dostepna_ilosc)
		VALUES(@nazwa_dania,@cena,@id_kategorii,@opis,@dostepna_ilosc)
		COMMIT TRAN Dodaj_danie
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Dodaj_danie
		DECLARE @errorMsg NVARCHAR(2048) = 'Błąd dodania dania: '+ERROR_MESSAGE();
		THROW 52000,@errorMsg,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_do_menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_do_menu]
	 @id_dania int,
	 @data_wprowadzenia date
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	BEGIN TRAN Dodaj_Do_Menu
	IF NOT EXISTS (SELECT * FROM Dania WHERE id_dania=@id_dania)
	BEGIN
		;THROW 52000, 'Nie ma takiego dania',1
	END
	IF NOT EXISTS (SELECT * FROM Menu WHERE @id_dania=ID_dania)
	BEGIN
		INSERT INTO Menu(ID_dania,Data_wprowadzenia)
		VALUES (@id_dania,@data_wprowadzenia)
	END
	ELSE IF (SELECT dbo.Ostatnie_Usuniecie_Z_Menu(@id_dania)) IS NULL
	BEGIN
		;THROW 52000, 'Nie mozna dodac do menu, poniewaz jest w menu',1
	END
	ELSE IF (SELECT dbo.Ostatnie_Usuniecie_Z_Menu(@id_dania))>@data_wprowadzenia
	BEGIN
		;THROW 52000, 'Danie nie moze zostac znow dodane przed data jego ostatniego usuniecia',1
	END
	ELSE
	BEGIN
		INSERT INTO Menu(ID_dania,Data_wprowadzenia)
		VALUES (@id_dania,@data_wprowadzenia)
	END
	COMMIT TRAN Dodaj_Do_Menu
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Dodaj_Do_Menu
		DECLARE @errorMsg nvarchar (2048) = 'Blad dodania do menu: '+ ERROR_MESSAGE () ;
		THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_klienta]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_klienta](
  @email VARCHAR(50),
  @telefon VARCHAR(9)) AS 
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    IF EXISTS(
      SELECT * FROM Klienci
      WHERE email=@email
    )
  BEGIN
  ;THROW 52000, 'Email jest juz zajety',1
  END
  IF EXISTS(
    SELECT * FROM Klienci
    WHERE nr_tel=@telefon
  )
  BEGIN
  ;THROW 52000, 'Telefon jest juz zajety',1
  END
  INSERT INTO Klienci(nr_tel,email) VALUES (@telefon,@email)
  END TRY
  BEGIN CATCH
    DECLARE @errorMsg NVARCHAR (2048) = 'Blad dodania klienta: '+ ERROR_MESSAGE () ;
    THROW 52000 , @errorMsg ,1;
  END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_klienta_firm]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_klienta_firm](
@email VARCHAR(50),
@telefon VARCHAR(9),
@nazwa_firmy VARCHAR(50),
@nip VARCHAR(10),
@ulica VARCHAR(50),
@kod VARCHAR(6),
@nazwa_miasta VARCHAR(50),
@nazwa_panstwa VARCHAR(50)) AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    BEGIN TRAN Dodaj_Klienta_Firm
    EXEC dbo.Dodaj_Klienta
    @email,
    @telefon
	DECLARE @id INT = @@IDENTITY
    INSERT INTO Klienci_Firmy
    VALUES (@id,@nazwa_firmy,@nip,@ulica,@kod,@nazwa_panstwa,@nazwa_miasta)
    COMMIT TRAN Dodaj_Klienta_Firm
  END TRY
  BEGIN CATCH
    ROLLBACK TRAN Dodaj_Klienta_Firm
    DECLARE @errorMsg NVARCHAR (2048) = 'Blad dodania klienta biznesowego: '+
    ERROR_MESSAGE() ;
    THROW 52000 , @errorMsg ,1;
  END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_klienta_ind]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_klienta_ind](
@imie VARCHAR(30),
@nazwisko VARCHAR(30),
@email VARCHAR(50),
@telefon VARCHAR(9)) AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    BEGIN TRAN Dodaj_Klienta_Ind
    EXEC dbo.Dodaj_Klienta
    @email,
    @telefon
    DECLARE @id INT = @@IDENTITY
    INSERT INTO Klienci_Ind(id_klienta,imie,nazwisko) VALUES (@id,@imie,@nazwisko)
    COMMIT TRAN Dodaj_Klienta_Ind
  END TRY
  BEGIN CATCH
    ROLLBACK TRAN Dodaj_Klienta_Ind
    DECLARE @errorMsg NVARCHAR (2048) = 'Blad dodania klienta indywidualnego: '+
    ERROR_MESSAGE () ;
    THROW 52000 , @errorMsg ,1;
  END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_pracownika]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_pracownika]
	@imie VARCHAR(50),
	@nazwisko VARCHAR(50)
AS 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		INSERT INTO Obsluga VALUES(@imie,@nazwisko)
	END TRY
	BEGIN CATCH
		DECLARE @errorMsg NVARCHAR(2048) = 'Blad dodania pracownika '+ERROR_MESSAGE();
		THROW 52000,@errorMsg,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_rabat]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_rabat]
	@wysokosc_rabatu float,
	@data_wprowadzenia date=null,
	@data_zdjecia date=null
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	IF NOT @wysokosc_rabatu BETWEEN 0 AND 1
	BEGIN
		;THROW 52000, 'Rabat jest wartoscia z przedzialu od 0 do 1',1
	END
	IF @data_wprowadzenia is NULL
	BEGIN
		SET @data_wprowadzenia=GETDATE()
	END 
	INSERT INTO Rabaty(wysokosc_rabatu,data_wprowadzenia,data_zdjecia)
	VALUES (@wysokosc_rabatu,@data_wprowadzenia,@data_zdjecia) 
	END TRY
	BEGIN CATCH
		DECLARE @errorMsg nvarchar (2048) = 'Blad dodania rabatu: '+ ERROR_MESSAGE () ;
		 THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_rabat_ind_jednorazowy]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_rabat_ind_jednorazowy]
	@wymagana_kwota MONEY,
	@wysokosc_rabatu FLOAT,
	@data_wprowadzenia DATE=NULL,
	@data_zdjecia DATE=NULL,
	@waznosc INT
AS
	BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	BEGIN TRAN Dodaj_Rabat_Ind_Jedn
	IF @waznosc<=0
	BEGIN
		;THROW 52000, 'Rabat musi miec waznosc przynajmniej 1 dzien',1
	END
	IF @wymagana_kwota<=0
	BEGIN
		;THROW 52000, 'Wymagana kwota rabatu musi byc dodatnia',1
	END
	IF @data_wprowadzenia IS NULL
	BEGIN
		SET @data_wprowadzenia=GETDATE()
	END
	EXEC Dodaj_Rabat
		@wysokosc_rabatu,
		@data_wprowadzenia,
		@data_zdjecia
	DECLARE @id INT = @@IDENTITY
	INSERT INTO Rabaty_Ind_Jednorazowe(ID_rabatu,Waznosc,wymagan_kwota)
	VALUES (@id,@waznosc,@wymagana_kwota)
	COMMIT TRAN Dodaj_Rabat_Ind_Jedn
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Dodaj_Rabat_Ind_Jedn
		DECLARE @errorMsg NVARCHAR (2048) = 'Blad dodania rabatu: '+ ERROR_MESSAGE () ;
		THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_rabat_ind_staly]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_rabat_ind_staly]
	@wysokosc_rabatu FLOAT,
	@data_wprowadzenia DATE=NULL,
	@data_zdjecia DATE=NULL,
	@liczba_zamowien INT,
	@minimalna_kwota MONEY
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	BEGIN TRAN Dodaj_Rabat_Ind_Staly
	IF @liczba_zamowien<=0
	BEGIN
		;THROW 52000, 'Minimalna ilosc zamowien musi byc liczba dodatnia calkowita',1
	END
	IF @minimalna_kwota < 0
	BEGIN
		;THROW 52000, 'Minimalna kwota zamowienia musi byc liczba dodatnia calkowita',1
	END
	DECLARE @id_poprzedniego INT = (SELECT ri.ID_rabatu FROM Rabaty_Ind_Stale ri
	INNER JOIN Rabaty r ON r.ID_rabatu=ri.ID_rabatu WHERE r.Data_zdjecia IS NULL)
	IF @id_poprzedniego IS NOT NULL
	BEGIN
		UPDATE Rabaty SET Data_zdjecia=@data_wprowadzenia WHERE
		@id_poprzedniego=ID_rabatu
	END
	EXEC Dodaj_rabat
	@wysokosc_rabatu,
	@data_wprowadzenia,
	@data_zdjecia

	DECLARE @id_rabatu INT=@@IDENTITY
	INSERT INTO Rabaty_Ind_Stale(ID_rabatu,minimalna_kwota,liczba_zamowien)
	VALUES (@id_rabatu,@minimalna_kwota,@liczba_zamowien)
	COMMIT TRAN Dodaj_Rabat_Ind_Staly
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Dodaj_Rabat_Ind_Staly
		DECLARE @errorMsg NVARCHAR (2048) = 'Blad dodania rabatu: '+ ERROR_MESSAGE () ;
		THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_stolik]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_stolik]
	@max_miejsc INT,
	@dostepny VARCHAR(1) = 'T'
AS 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		INSERT INTO Stoliki VALUES(@max_miejsc,@dostepny);
	END TRY
	BEGIN CATCH
		DECLARE @errorMsg NVARCHAR(2048) = 'Blad dodanina stolika '+ERROR_MESSAGE();
		THROW 52000,@errorMsg,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Dodaj_Zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dodaj_Zamowienie]
	@id_klienta INT,
	@data_zamowienia DATETIME,
	@data_odbioru DATETIME = NULL,
	@czy_na_wynos VARCHAR(1),
	@id_pracownika INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	BEGIN TRAN Dodaj_Zamowienie
	IF NOT EXISTS (SELECT * FROM Klienci WHERE @id_klienta=ID_klienta)
	BEGIN
		;THROW 52000, 'Nie ma takiego klienta',1
	END
	IF @data_odbioru IS NULL AND @czy_na_wynos='T'
	BEGIN
		;THROW 52000, 'Przy zamawianiu na wynos trzeba podac date odbioru',1
	END
	IF @data_odbioru is NULL
	BEGIN
		SET @data_odbioru=DATEADD(hh,1,@data_zamowienia)
	END
	IF NOT EXISTS (SELECT * FROM Obsluga WHERE ID_pracownika=@id_pracownika)
	BEGIN
		;THROW 52000, 'Zamowienie obsluguje nieuprawniona osoba',1
	END
	DELETE FROM Aktualnie_Przyznane_Rabaty WHERE @id_klienta=ID_klienta AND
	Data_wygasniecia IS NOT NULL AND Data_wygasniecia<GETDATE()
	DELETE FROM Aktualnie_Przyznane_Rabaty WHERE @id_klienta=ID_klienta AND
	ID_rabatu IN(
	SELECT ID_rabatu FROM Rabaty WHERE Data_zdjecia IS NOT NULL)
	IF @id_klienta IN (SELECT ID_klienta FROM Klienci_Ind)
	BEGIN
	EXEC Aktualizuj_Rabat_Ind_Staly
		@id_klienta
	EXEC Aktualizuj_Rabat_Ind_Jednorazowy
		@id_klienta
	END
	ELSE
	BEGIN
	INSERT INTO Zamowienia(ID_klienta,Data_zamowienia,Data_odbioru,czy_na_wynos,id_pracownika,id_rezerwacji)
	VALUES (@id_klienta,@data_zamowienia,@data_odbioru,@czy_na_wynos,@id_pracownika,NULL)
	DECLARE iter CURSOR
	FOR
	SELECT a.ID_rabatu
	FROM Aktualnie_Przyznane_Rabaty a
	INNER JOIN Rabaty r ON r.ID_rabatu=a.ID_rabatu
	WHERE @id_klienta=a.ID_klienta 
	DECLARE @rabat int
	OPEN iter
	FETCH NEXT FROM iter INTO @rabat
	WHILE @@FETCH_STATUS = 0
	BEGIN
	DECLARE @data_wygasniecia date=(SELECT Data_wygasniecia FROM
	Aktualnie_Przyznane_Rabaty
	WHERE @rabat=ID_rabatu AND @id_klienta=ID_klienta)
	IF @data_wygasniecia<GETDATE()
	BEGIN
	EXEC Odbierz_Rabat_Klientowi
		@rabat,
		@id_klienta
	END
	FETCH NEXT FROM iter INTO @rabat
	END
	CLOSE iter
	DEALLOCATE iter
	END
	COMMIT TRAN Dodaj_Zamowienie
	END TRY
	BEGIN CATCH
	ROLLBACK TRAN Dodaj_Zamowienie
	DECLARE @errorMsg nvarchar (2048) = 'Blad dodania zamowienia: '+ ERROR_MESSAGE () ;
		THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Odbierz_rabat_klientowi]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Odbierz_rabat_klientowi]
(
	@id_rabatu INT,
	@id_klienta INT
)
AS 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN Odbierz_Rabat
			IF NOT EXISTS(SELECT * FROM Rabaty WHERE id_rabatu = @id_rabatu)
			BEGIN
				;THROW 52000,'Nie ma takiego rabatu',1
			END
			IF NOT EXISTS(SELECT * FROM Klienci WHERE id_klienta = @id_klienta)
			BEGIN 
				;THROW 52000,'Nie ma takiego klienta w bazie',1
			END
			DELETE FROM Aktualnie_przyznane_rabaty WHERE @id_rabatu = @id_rabatu
		COMMIT TRAN Odbierz_Rabat
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Odbierz_Rabat
		DECLARE @errorMsg NVARCHAR(2048) = 'Blad wygaszania rabatu '+ERROR_MESSAGE();
		THROW 52000,@errorMsg,1
	END CATCH
END 
GO
/****** Object:  StoredProcedure [dbo].[Przyznaj_rabat_klientowi]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Przyznaj_rabat_klientowi]
	@id_rabatu INT,
	@id_klienta INT,
	@data_przyznania DATE = NULL,
	@data_wygasniecia DATE = NULL
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		IF NOT EXISTS( SELECT * FROM Rabaty WHERE id_rabatu = @id_rabatu)
		BEGIN
			;THROW 52000,'Nie ma takiego rabatu',1;
		END
		DECLARE @data_zdjecia DATE = (SELECT data_zdjecia FROM Rabaty WHERE id_rabatu = @id_rabatu);
		IF NOT (@data_zdjecia IS NULL OR @data_zdjecia >= GETDATE())
		BEGIN 
			;THROW 52000,'Ten rabat utracil waznosc',1;
		END
		IF NOT EXISTS(SELECT * FROM Klienci WHERE id_klienta = @id_klienta)
		BEGIN
			;THROW 52000,'Nie ma takiego klienta',1;
		END
		IF EXISTS (SELECT * FROM Klienci_firmy WHERE id_klienta = @id_klienta) AND
		(EXISTS (SELECT * FROM Rabaty_ind_jedn WHERE id_rabatu = @id_rabatu) OR
		EXISTS (SELECT * FROM Rabaty_ind_stale WHERE id_rabatu = @id_rabatu))
		BEGIN 
			;THROW 52000,'Proba przyznania rabatu firmie',1;
		END
		IF EXISTS(SELECT * FROM Klienci_ind WHERE id_klienta = @id_klienta) AND
		NOT EXISTS (SELECT * FROM Rabaty_ind_jedn WHERE id_rabatu = @id_rabatu) AND 
		NOT EXISTS (SELECT * FROM Rabaty_ind_stale WHERE id_rabatu = @id_rabatu)
		BEGIN
			;THROW 52000,'Proba przyznania nieistniejacego rabatu dla klienta indywidualnego',1;
		END
		IF @data_przyznania IS NULL 
		BEGIN
			SET @data_przyznania = GETDATE();
		END
		IF EXISTS(SELECT * FROM Rabaty_ind_jedn WHERE id_rabatu = @id_rabatu)
		BEGIN
			DECLARE @waznosc INT = (SELECT waznosc FROM Rabaty_ind_jedn WHERE id_rabatu = @id_rabatu);
			SET @data_wygasniecia = DATEADD(dd,@waznosc,@data_przyznania)
		END
		INSERT INTO Aktualnie_przyznane_rabaty(id_rabatu,id_klienta,data_przyznania,data_wygasniecia)
		VALUES(@id_rabatu,@id_klienta,@data_przyznania,@data_wygasniecia)
	END TRY
	BEGIN CATCH
		DECLARE @errorMsg NVARCHAR(2048) = 'Blad przyznania rabatu '+ERROR_MESSAGE();
		THROW 52000,@errorMsg,1;
	END CATCH
END 
GO
/****** Object:  StoredProcedure [dbo].[Usun_polowe_pozycji_z_menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Usun_polowe_pozycji_z_menu]
	@data date
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE Menu SET Data_zdjecia=GETDATE() WHERE id_pozycji IN(
	SELECT TOP 50 PERCENT a.id_pozycji FROM dbo.Pokaz_Menu_Dnia(@data) a
	INNER JOIN dbo.Pokaz_Menu_Dnia(DATEADD(day,-14,@data)) b ON a.id_pozycji = b.id_pozycji
	ORDER BY a.Data_wprowadzenia ASC)
END
GO
/****** Object:  StoredProcedure [dbo].[Usun_z_menu]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Usun_z_menu]
	 @id_dania int,
	 @data_zdjecia date
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
	BEGIN TRAN Usun_Z_Menu
	IF NOT EXISTS (SELECT * FROM Menu WHERE @id_dania=ID_dania AND Data_zdjecia IS NULL)
	BEGIN
		;THROW 52000, 'Nie ma takiej pozycji obecnie w Menu',1
	END
	DECLARE @id_pozycji int = (SELECT ID_pozycji FROM Menu WHERE ID_dania=@id_dania AND Data_zdjecia IS NULL)
	IF @data_zdjecia<GETDATE()
	BEGIN
		;THROW 52000, 'Data zdjecia nie moze byc chwila z przeszlosci',1
	END
	IF @data_zdjecia<(SELECT Data_wprowadzenia FROM Menu WHERE ID_dania=@id_dania AND Data_zdjecia IS NULL)
	BEGIN
		;THROW 52000, 'Data zdjecia nie moze wczesniejsza niz dodania',1
	END
	UPDATE Menu SET Data_zdjecia=@data_zdjecia
	COMMIT TRAN Usun_Z_Menu
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN Usun_Z_Menu
		DECLARE @errorMsg nvarchar (2048) = 'Blad usuniecia z menu: '+ ERROR_MESSAGE () ;
		THROW 52000 , @errorMsg ,1;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Wystaw_fakture_miesieczna]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Wystaw_fakture_miesieczna]
    @id_klienta INT,
    @miesiac INT,
    @rok INT
AS 
BEGIN
    
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM Zamowienia 
            WHERE id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok)
            THROW 50001,'Brak zamówień w tym miesiącu!',1
        IF NOT EXISTS (SELECT * FROM Zamowienia 
            WHERE id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok AND status_faktury IS NULL)
            THROW 50001,'Na wszystkie zamówienia w tym miesiącu faktura została już wystawiona!',1
        ELSE
            UPDATE Zamowienia
            SET status_faktury = 'M'
            WHERE id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok AND status_faktury IS NULL
 
            UPDATE Faktury
            SET data_wystawienia = GETDATE()
            WHERE id_faktury IN (SELECT id_faktury FROM Zamowienia
                WHERE id_klienta = @id_klienta AND MONTH(data_odbioru) = @miesiac AND YEAR(data_odbioru) = @rok AND status_faktury IS NULL);
    END TRY
    BEGIN CATCH
        DECLARE @errorMsg NVARCHAR(2048) = 'Blad wystawienia faktury: '+ ERROR_MESSAGE();
        THROW 52000,@errorMsg,1;
    END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Wystaw_fakture_na_zamowienie]    Script Date: 20.01.2022 21:01:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Wystaw_fakture_na_zamowienie]
    @id_zamowienia INT
AS 
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM Zamowienia WHERE id_zamowienia = @id_zamowienia)
            THROW 50001,'Nie ma takiego zamowienia!',1
        ELSE
            UPDATE Zamowienia
            SET status_faktury = 'J'
            WHERE id_zamowienia = @id_zamowienia;
 
            UPDATE Faktury
            SET data_wystawienia = GETDATE()
            WHERE id_faktury = (SELECT id_faktury FROM Zamowienia WHERE id_zamowienia = @id_zamowienia);
    END TRY
    BEGIN CATCH
        DECLARE @errorMsg NVARCHAR(2048) = 'Blad wystawienia faktury '+ ERROR_MESSAGE();
        THROW 52000,@errorMsg,1;
    END CATCH
END
GO
USE [master]
GO
ALTER DATABASE [u_tekielsk] SET  READ_WRITE 
GO
