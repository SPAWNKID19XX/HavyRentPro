# Build stage
FROM node:20-alpine AS build                                                                       
WORKDIR /app                                                                                       
COPY package*.json ./                                                                              
RUN npm install                                           
COPY . .
RUN npm run build

# Production stage                                                                                 
FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html                                                  
EXPOSE 80                                                                                          
                                                                                                    
# Dev stage                                                                                        
FROM node:20-alpine AS dev                                
WORKDIR /app                                                                                       
COPY package*.json ./                                     
RUN npm install
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
