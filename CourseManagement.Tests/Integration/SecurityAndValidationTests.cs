using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using CourseManagement.API.Extensions;
using CourseManagement.API.Mvc.ViewModels;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class SecurityAndValidationTests
{
    [Fact]
    public void GetUserId_ReturnsIdentifierFromNameIdentifierClaim()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
        [new Claim(ClaimTypes.NameIdentifier, "42")],
        "test"));

        Assert.Equal(42, principal.GetUserId());
    }

    [Fact]
    public void GetUserId_RejectsMissingOrInvalidClaim()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity([], "test"));

        Assert.Throws<UnauthorizedAccessException>(() => principal.GetUserId());
    }

    [Fact]
    public void IsAdmin_RecognizesAdminRole()
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
        [new Claim(ClaimTypes.Role, "Admin")],
        "test"));

        Assert.True(principal.IsAdmin());
    }

    [Fact]
    public void ChangePasswordViewModel_RejectsShortOrMismatchedPassword()
    {
        var model = new ChangePasswordViewModel
        {
            CurrentPassword = "CurrentPassword!1",
            NewPassword = "short",
            ConfirmNewPassword = "different"
        };

        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(model);
        var isValid = Validator.TryValidateObject(model, context, validationResults, validateAllProperties: true);

        Assert.False(isValid);
        Assert.Contains(validationResults, result => result.MemberNames.Contains(nameof(ChangePasswordViewModel.NewPassword)));
        Assert.Contains(validationResults, result => result.MemberNames.Contains(nameof(ChangePasswordViewModel.ConfirmNewPassword)));
    }
}
