using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers;

[Route("api/[controller]")]
[ApiController]
public class HomePageController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public HomePageController(FreshFoodContext context)
    {
        _context = context;
    }

    public sealed record HomeHeroDto(
        string Eyebrow,
        string Title,
        string Highlight,
        string Subtitle,
        string ImageUrl,
        string PrimaryCtaText,
        string PrimaryCtaHref,
        string SecondaryCtaText,
        string? SecondaryCtaHref,
        string Feature1Title,
        string Feature1Sub,
        string Feature2Title,
        string Feature2Sub
    );

    public sealed record HomeRootsDto(
        string Subheading,
        string Title,
        string Paragraph1,
        string Paragraph2,
        string ImageUrl,
        string Stat1Value,
        string Stat1Label,
        string Stat2Value,
        string Stat2Label
    );

    public sealed record HomeSeasonalCardDto(string Title, string ImageUrl);

    public sealed record HomeSeasonalDto(string Heading, string Subheading, IReadOnlyList<HomeSeasonalCardDto> Cards);

    public sealed record HomePageSettingsDto(HomeHeroDto Hero, HomeRootsDto Roots, HomeSeasonalDto Seasonal);

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false
    };

    private static HomePageSettingsDto Default()
    {
        return new HomePageSettingsDto(
            new HomeHeroDto(
                "FRESH FROM THE FARM",
                "Thực phẩm sạch cho",
                "cuộc sống xanh",
                "Mang tinh hoa của đất mẹ đến bàn ăn gia đình bạn. Chúng tôi cam kết 100% hữu cơ,\n              tươi mới và canh tác bền vững.",
                "https://lh3.googleusercontent.com/aida-public/AB6AXuAn0_mNhh8RAPtDRh5dXiS0PwqdeokDtFRsYYdHuwNzUd8DUP-XK0LCy3fRsasW6dte8-HP5n76MS78rIwCFlIXB_KoyZHUcublemfM8U8s7E-DaT3kwb8Rf-aUW6_ffI3mA1DBRY8A1prT7MxWir9RavBVLMd5uwlQbf2244qVhU9tRG5QKHw5liPbu7L1kboFE0LcFFVg3M20VNc2Z_BT8h-MijK_VjDfGHRrclE6pjmN0dn1X4iVzSCCAvJ7wP8rqExns9kIZA8",
                "Shop Collections",
                "/shop",
                "View Story",
                null,
                "Giao hàng trong 2h",
                "Nhanh chóng & tiện lợi",
                "Đảm bảo ATVSTP",
                "Kiểm duyệt nghiêm ngặt"
            ),
            new HomeRootsDto(
                "OUR ROOTS",
                "Lớn lên với niềm đam mê,được truyền tải bằng trái tim.",
                "Từ những ngày đầu tiên tại nông trại hữu cơ nhỏ, chúng tôi luôn tin rằng thực phẩm tốt nhất là thực phẩm được nuôi dưỡng bởi tự nhiên và sự chăm sóc từ tâm.",
                "Mỗi sản phẩm tại FreshFood đều trải qua quy trình kiểm soát nghiêm ngặt từ hạt giống đến khi trao tận tay khách hàng. Không hóa chất, không thuốc trừ sâu - chỉ có sự tinh khiết tuyệt đối cho sức khỏe gia đình bạn.",
                "https://lh3.googleusercontent.com/aida-public/AB6AXuDsj_dBOI4I0rXNR9uejFIaPEYVYQLiGunw26FXWSFWv8bh-uXHvGgsQsg_XTphaN30FjcrZ-zZvN1zLeAy9-L0P21Vb5NEEbJZ-udrnGjuUD8oXHa4P3CgVcJ44tFQXwszRhO4rqxV3sGWuBfqtJ7aAcKYwZpFTiIEiEn6Q0bK0gDvCvPdtucaAkTpSSL_YANkAVAhLYv5EFW-rtmR0wFVAIEamv0iDUPhzmDHsk6HgLEDPQgOGkgMEv47w-wVzGBjlAicFc822N8",
                "100%",
                "Organic Certified",
                "24h",
                "Farm to Door"
            ),
            new HomeSeasonalDto(
                "Bộ sưu tập theo mùa",
                "Đón mùa vụ tươi ngon nhất trong năm. Khám phá những bộ sưu tập được\n              tuyển chọn theo mùa vụ hiện tại.",
                new List<HomeSeasonalCardDto>
                {
                    new("The Spring Greens", "https://images.pexels.com/photos/60597/dahlia-red-blossom-bloom-60597.jpeg"),
                    new("Earthy Roots", "https://images.pexels.com/photos/1301856/pexels-photo-1301856.jpeg"),
                    new("Sun-Kissed Fruits", "https://images.pexels.com/photos/1132047/pexels-photo-1132047.jpeg"),
                }
            )
        );
    }

    [HttpGet]
    public async Task<ActionResult<HomePageSettingsDto>> Get(CancellationToken ct)
    {
        var row = await _context.HomePageSettings.AsNoTracking().FirstOrDefaultAsync(x => x.Id == 1, ct);
        if (row == null || string.IsNullOrWhiteSpace(row.SettingsJson))
            return Ok(Default());

        try
        {
            var dto = JsonSerializer.Deserialize<HomePageSettingsDto>(row.SettingsJson, JsonOpts);
            return Ok(dto ?? Default());
        }
        catch
        {
            return Ok(Default());
        }
    }
}

