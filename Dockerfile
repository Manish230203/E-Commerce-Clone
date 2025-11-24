# Use a lightweight Nginx image
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy all static files (html, css, js, images) into nginx web root
COPY . /usr/share/nginx/html

# Expose port 80 for HTTP traffic
EXPOSE 80

# Use the default nginx startup command
CMD ["nginx", "-g", "daemon off;"]
