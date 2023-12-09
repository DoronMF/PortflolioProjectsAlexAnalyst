SELECT  location,
		date,
		total_cases,
		new_cases,
		total_deaths,population
FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
order by 4 desc, 3 desc

-- Looking at Total cases vs TotalDeaths
-- Shows the likelihood of dying if you contract covid in your country	

SELECT  location,
        date,
		total_cases,
		total_deaths,
		cast(total_deaths as decimal(12,0))/cast(total_cases as decimal(12,0))  * 100 mortality_perc
FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
where location like '%states%'
order by 2

--Looking at total cases vs Population
-- Shows what percent of Population got infected
select population_infected.*, 
	   substring(cast(pop_infected as nvarchar),1,charindex(cast(pop_infected as nvarchar),'.')+6)
from
      
		(SELECT  location,
				date,
				total_cases,
				population,
				cast(total_cases as decimal(12,0))/cast(population as decimal(12,0))  * 100 as pop_infected
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
		where location like '%states%'
		) as population_infected
order by 1, 2

--Looking at countries with highest infection rate compared to population
select location, 
       max(pop_infected) as highest_infection_rate
from  (
		SELECT	location,
				date,
				total_cases,
				population,
				cast(total_cases as decimal(12,0))/cast(population as decimal(12,0))  * 100 as pop_infected
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
		where date <= '2021-04-30'
      ) as infection_rate
Group by location
Order by 2 desc


--Looking at countries with highest death count per population
select location,
	   max(cast(total_deaths as int)) as tot_deaths,
       max(pop_died) as highest_death_rate
from  (
		SELECT	location,
				date,
				total_cases,
				population,
				total_deaths,
				cast(total_deaths as decimal(12,0))/cast(population as decimal(12,0))  * 100 as pop_died
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
		where date <= '2021-04-30'
		  and continent is not null 
      ) as infection_rate
Group by location
Order by 2 desc



-- Lets break down things by continent
select location,
	   max(cast(total_deaths as int)) as tot_deaths,
       max(pop_died) as highest_death_rate
from  (
		SELECT	location,
				date,
				total_cases,
				population,
				total_deaths,
				cast(total_deaths as decimal(12,0))/cast(population as decimal(12,0))  * 100 as pop_died
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
		where date <= '2021-04-30'
		  and continent is null 
		  and location not like '%income%'
      ) as infection_rate
Group by location
Order by 2 desc


-- Global numbers by day
select  date, 
		sum(cast(new_deaths as int)) as tot_deaths,
		sum(new_cases) as tot_cases,
		 
        nullif(sum(cast(new_deaths as int)),0) / nullif(sum(new_cases),0)  * 100 as death_prc
from [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
where continent is not null
 and date <= '2021-04-30'
group by date
order by date 

-- Total Global numbers 
select  sum(cast(new_deaths as int)) as tot_deaths,
		sum(new_cases) as tot_cases,
		nullif(sum(cast(new_deaths as int)),0) / nullif(sum(new_cases),0)  * 100 as death_prc
from [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$]
where continent is not null
 and date <= '2021-04-30'


 -- Now we are bringing in the vaccinations tables and doing a join
-- Looking at Total Population Vs Vaccinations
With population_vs_vaccinations
as 
		(SELECT dea.continent,
				dea.location,
				dea.date,
				dea.population,
				vac.new_vaccinations,
				SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) 
					as rolling_people_vaccinated,
				SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) /
				   dea.population * 100 as vaccination_perc
                 
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$] dea
			 JOIN [PortfolioProjectAlexTheAnalyst].[dbo].[CovidVacinations$] vac
				  ON dea.location = vac.location and dea.date = vac.date
		WHERE dea.continent is not null 
		  AND dea.date <= '2021-04-30'
		  ),


pop_vac_per_loc
as     (select population_vs_vaccinations.*,
			  max(vaccination_perc) over (partition by location) as pop_vaccinated	
	   from population_vs_vaccinations
	   )

select * from pop_vac_per_loc
where vaccination_perc = pop_vaccinated
  and new_vaccinations is not null

Use PortfolioProjectAlexTheAnalyst;
--TEMP TABLE
-- Creating a temp table from the data above
DROP TABLE if exists #PercentPopulationVaccincated
create Table #PercentPopulationVaccincated
	(continent nvarchar(255),
	 location nvarchar(255),
	 date datetime,
	 population numeric,
	 new_vaccinations numeric,
	 rolling_people_vaccinated numeric
	 )

INSERT INTO #PercentPopulationVaccincated
SELECT			dea.continent,
				dea.location,
				dea.date,
				dea.population,
				vac.new_vaccinations,
				SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) 
					as rolling_people_vaccinated
				--,SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) /
				--   dea.population * 100 as vaccinations_percentage
                 
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$] dea
			 JOIN [PortfolioProjectAlexTheAnalyst].[dbo].[CovidVacinations$] vac
				  ON dea.location = vac.location and dea.date = vac.date
		WHERE dea.continent is not null 
		  AND dea.date <= '2021-04-30'

select *, (rolling_people_vaccinated/population) * 100 as rolling_vaccincation_percentage 
FROM #PercentPopulationVaccincated


--VIEWS
-- Creating View to store data for later visualizations

Use PortfolioProjectAlexTheAnalyst;
Create View PercentPopulationVaccincated
AS
SELECT			dea.continent,
				dea.location,
				dea.date,
				dea.population,
				vac.new_vaccinations,
				SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) 
					as rolling_people_vaccinated
				--,SUM(CONVERT(INT,new_vaccinations)) over (partition by dea.location order by dea.location, dea.date) /
				--   dea.population * 100 as vaccinations_percentage
                 
		FROM [PortfolioProjectAlexTheAnalyst].[dbo].[CovidDeaths$] dea
			 JOIN [PortfolioProjectAlexTheAnalyst].[dbo].[CovidVacinations$] vac
				  ON dea.location = vac.location and dea.date = vac.date
		WHERE dea.continent is not null 
		  AND dea.date <= '2021-04-30'