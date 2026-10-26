"""Load the actual Compose-served Flutter web build and join through its UI."""
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True, args=['--no-sandbox'])
    context = browser.new_context(viewport={'width': 1280, 'height': 900})
    page = context.new_page()
    external = []
    def route(request):
        from urllib.parse import urlparse
        if urlparse(request.request.url).hostname not in ('127.0.0.1', 'localhost'):
            external.append(request.request.url)
            request.abort()
        else:
            request.continue_()
    context.route('**/*', route)
    try:
        page.goto('http://127.0.0.1:7357/', wait_until='networkidle')
        # Flutter canvas rendering exposes its controls after accessibility activation.
        page.locator('flt-semantics-placeholder').evaluate('(node) => node.click()')
        page.get_by_role('textbox', name='Display name', exact=True).fill('Compose browser reviewer')
        page.get_by_role('textbox', name='Group password', exact=True).fill('local-group-password')
        page.get_by_role('button', name='Join group', exact=True).click()
        page.get_by_role('button', name='SEND ALERT', exact=True).wait_for(timeout=20000)
        page.get_by_text('Joined as Compose browser reviewer', exact=True).wait_for()
        page.get_by_text('Connected for live alerts', exact=True).wait_for(timeout=20000)
        assert not external, f'Unexpected external runtime requests: {external}'
        print('Actual Compose web build loaded runtime config, joined and connected to Realtime through its UI.')
    except Exception:
        print('Browser URL:', page.url)
        print('Semantics:', page.locator('flt-semantics').evaluate_all('(nodes) => nodes.map(n => ({role:n.getAttribute("role"),label:n.getAttribute("aria-label"),text:n.textContent}))'))
        print('External requests:', external)
        raise
    finally:
        browser.close()
