# Stage 1: Build the application
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["freshfood-be/freshfood-be.csproj", "freshfood-be/"]
RUN dotnet restore "freshfood-be/freshfood-be.csproj"

# Copy the rest of the application code
COPY . .
WORKDIR "/src/freshfood-be"

# Build and publish the application
RUN dotnet publish "freshfood-be.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Run the application
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Set environment variable to listen on port 5013
ENV ASPNETCORE_URLS=http://+:5013
EXPOSE 5013

# Copy the published output from the build stage
COPY --from=build /app/publish .

# Set the entry point for the application
ENTRYPOINT ["dotnet", "freshfood-be.dll"]
