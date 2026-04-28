using Microsoft.AspNetCore.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Hosting;
using System.IO;

namespace freshfood_be.Middlewares
{
    public class MaintenanceMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly string _lockFile;

        public MaintenanceMiddleware(RequestDelegate next, IWebHostEnvironment env)
        {
            _next = next;
            _lockFile = Path.Combine(env.ContentRootPath, "maintenance.lock");
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var path = context.Request.Path.Value ?? "";

            // Allow CORS preflight requests
            if (HttpMethods.IsOptions(context.Request.Method))
            {
                await _next(context);
                return;
            }

            // Check if maintenance mode is enabled
            if (File.Exists(_lockFile))
            {
                bool isAdmin = context.User?.IsInRole("Admin") == true;
                
                // Allow admin, login endpoint, and static files
                bool isLogin = path.StartsWith("/api/Account/login", System.StringComparison.OrdinalIgnoreCase);
                bool isStatic = !path.StartsWith("/api/", System.StringComparison.OrdinalIgnoreCase);

                if (!isAdmin && !isLogin && !isStatic)
                {
                    context.Response.StatusCode = 503;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync("{\"message\": \"Hệ thống đang được bảo trì. Vui lòng quay lại sau.\", \"isMaintenance\": true}");
                    return;
                }
            }

            await _next(context);
        }
    }
}
