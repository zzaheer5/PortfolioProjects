/* Covid 19 Data Exploration */

SELECT *
FROM COVIDPROJECT.dbo.CovidDeaths

SELECT *
FROM COVIDPROJECT.dbo.CovidVaccinations

-- create new formatted date column 

ALTER TABLE COVIDPROJECT.dbo.CovidDeaths
ADD dateconverted Date

UPDATE COVIDPROJECT.dbo.CovidDeaths
SET dateconverted = CONVERT(Date, date)

-- creating a year column

ALTER TABLE COVIDPROJECT.dbo.CovidDeaths
ADD year nvarchar(255)

UPDATE COVIDPROJECT.dbo.CovidDeaths
SET year = LEFT(CAST(dateconverted AS varchar),4)

-- average life expectancy per country 

SELECT DISTINCT location, life_expectancy
FROM COVIDPROJECT.dbo.CovidVaccinations
WHERE iso_code NOT LIKE '%owid%' -- removes continent values from the location column 
ORDER BY life_expectancy DESC

-- total cases in each continent for each year 

SELECT continent, MAX(total_cases) AS total_cases_in_year, year
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null 
GROUP BY continent, year
ORDER BY year desc

-- total deaths in each continent for each year 

SELECT continent, MAX(CAST(Total_deaths AS int)) AS total_deaths_in_year, year
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null 
GROUP BY continent, year
ORDER BY year desc

-- percentage of each country over 65 

SELECT DISTINCT location, aged_65_older
FROM COVIDPROJECT.dbo.CovidVaccinations
WHERE iso_code NOT LIKE '%owid%'
ORDER BY aged_65_older DESC

-- likelihood of dying if you contracted covid in each country by date 

SELECT location, dateconverted, total_cases,total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null AND total_cases is not null AND total_deaths is not null AND population is not null AND iso_code NOT LIKE '%owid%' -- removes NULL and duplicate values 
ORDER by 1,2

-- percentage of population infected 

SELECT location, dateconverted, population, total_cases, (total_cases/population)*100 AS PercentPopulationInfected
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null AND total_cases is not null AND total_deaths is not null AND population is not null AND iso_code NOT LIKE '%owid%'
ORDER BY 1, 2 

-- countries with the highest infection rate in relation to population 

SELECT location, population, MAX(total_cases) AS HighestInfectionCount,  MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null AND total_cases is not null AND total_deaths is not null AND population is not null AND iso_code NOT LIKE '%owid%'
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

-- countries with the highest death count per population 

SELECT location, MAX(CAST(Total_deaths AS int)) AS TotalDeathCount
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null AND total_cases is not null AND total_deaths is not null AND population is not null AND iso_code NOT LIKE '%owid%'
GROUP BY location
ORDER BY TotalDeathCount DESC

-- contintents with the highest death count per population

SELECT location, MAX(CAST(Total_deaths AS int)) AS TotalDeathCount
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is null AND location not in ('European Union', 'International', 'World', 'Upper middle income', 'High income', 'Lower middle income', 'Low income')
GROUP BY location 
ORDER BY TotalDeathCount DESC

-- covid fatality rate in regards to total deaths and cases 

SELECT SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS int)) AS total_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS DeathPercentage
FROM COVIDPROJECT.dbo.CovidDeaths
WHERE continent is not null 

-- rolling number of covid tests given in each country

SELECT death.continent, death.location, death.dateconverted, death.population, vac.new_tests, positive_rate
, SUM(CONVERT(int, vac.new_tests)) OVER (PARTITION BY death.location ORDER BY death.location, Death.dateconverted) AS RollingNumberOfTests
FROM COVIDPROJECT.dbo.CovidDeaths death
JOIN COVIDPROJECT.dbo.CovidVaccinations vac
	ON death.location = vac.location 
	AND death.date = vac.date
WHERE death.iso_code NOT LIKE '%owid%'
ORDER BY 2, 3

-- rolling number of vaccines administered in each country 

SELECT death.continent, death.location, death.dateconverted, death.population, vac.new_vaccinations
, SUM(CONVERT(int, vac.new_vaccinations)) OVER (PARTITION BY death.location ORDER BY death.location, Death.dateconverted) AS RollingNumberOfVaccines
FROM COVIDPROJECT.dbo.CovidDeaths death
JOIN COVIDPROJECT.dbo.CovidVaccinations vac
	ON death.location = vac.location 
	AND death.date = vac.date
WHERE death.iso_code NOT LIKE '%owid%'
ORDER BY 2, 3

-- CTE, number of fully vaccinated people in each country and percentage of individuals fully vaccinated compared to population 

WITH FullyVac (location, population, fully_vaccinated, PercentFullyVaccinated) 
AS
(
SELECT vac.location, MAX(population) AS current_pop, MAX(CONVERT(numeric, vac.people_fully_vaccinated)) AS fully_vaccinated, MAX(CONVERT(numeric, vac.people_fully_vaccinated))/MAX(population)*100 AS PercentFullyVaccinated
FROM COVIDPROJECT.dbo.CovidVaccinations vac 
JOIN COVIDPROJECT.dbo.CovidDeaths death
	ON vac.location = death.location
	AND vac.date = death.date
WHERE vac.continent is not null AND vac.iso_code NOT LIKE '%owid%' AND death.population is not null
GROUP BY vac.location
)
SELECT*
FROM FullyVac
ORDER BY PercentFullyVaccinated DESC

-- temp table 

DROP TABLE IF exists #AgeOver65
CREATE TABLE #AgeOver65
(
Location nvarchar(255),
Population numeric,
aged_65_older numeric,
over_65_pop numeric
)

INSERT INTO #AgeOver65
SELECT DISTINCT death.location, death.population, vac.aged_65_older, (death.population*vac.aged_65_older)/100 AS pop_over_65
FROM COVIDPROJECT.dbo.CovidDeaths death
JOIN COVIDPROJECT.dbo.CovidVaccinations vac
	ON death.location = vac.location
	AND death.date = vac.date
WHERE death.iso_code NOT LIKE '%owid%'
ORDER BY pop_over_65 DESC
