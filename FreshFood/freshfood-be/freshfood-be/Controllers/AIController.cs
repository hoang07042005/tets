using Microsoft.AspNetCore.Mvc;
using freshfood_be.Services.AI;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AIController : ControllerBase
    {
        private readonly IAIService _aiService;

        public AIController(IAIService aiService)
        {
            _aiService = aiService;
        }

        [HttpPost("suggest-recipe")]
        public async Task<IActionResult> SuggestRecipe([FromBody] RecipeRequest request)
        {
            if (request.Ingredients == null || request.Ingredients.Count == 0)
            {
                return BadRequest("Danh sách nguyên liệu không được để trống.");
            }

            try
            {
                var suggestion = await _aiService.GetRecipeSuggestionAsync(request.Ingredients);
                return Ok(new { suggestion });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = ex.Message });
            }
        }
    }

    public class RecipeRequest
    {
        public List<string> Ingredients { get; set; } = new List<string>();
    }
}
