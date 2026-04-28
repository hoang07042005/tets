using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;
using System.IO;

namespace freshfood_be.Controllers.admin
{
    [Authorize(Roles = "Admin")]
    [Route("api/Admin/[controller]")]
    [ApiController]
    public class AdminMaintenanceController : ControllerBase
    {
        private readonly string _lockFile;

        public AdminMaintenanceController(IWebHostEnvironment env)
        {
            _lockFile = Path.Combine(env.ContentRootPath, "maintenance.lock");
        }

        [HttpGet]
        public ActionResult<object> GetStatus()
        {
            bool isMaintenance = System.IO.File.Exists(_lockFile);
            return Ok(new { isMaintenance });
        }

        [HttpPost("toggle")]
        public ActionResult<object> Toggle([FromBody] ToggleRequest req)
        {
            if (req.IsMaintenance)
            {
                if (!System.IO.File.Exists(_lockFile))
                {
                    System.IO.File.WriteAllText(_lockFile, "1");
                }
            }
            else
            {
                if (System.IO.File.Exists(_lockFile))
                {
                    System.IO.File.Delete(_lockFile);
                }
            }

            return Ok(new { isMaintenance = req.IsMaintenance });
        }

        public class ToggleRequest
        {
            public bool IsMaintenance { get; set; }
        }
    }
}
